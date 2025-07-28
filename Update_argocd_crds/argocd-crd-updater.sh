#!/bin/bash

# ArgoCD CRDs Update Script
# Author: DevOps Assistant
# Description: Safely updates ArgoCD Custom Resource Definitions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="argocd"
ARGOCD_VERSION="v2.14.11"  # Basado en tu values.yaml
BACKUP_DIR="./argocd-crd-backup-$(date +%Y%m%d-%H%M%S)"
TEMP_DIR="/tmp/argocd-crds"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    ArgoCD CRDs Update Manager${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Target Version: ${ARGOCD_VERSION}${NC}"
    echo -e "${BLUE}Namespace: ${NAMESPACE}${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    # Check curl/wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log_error "Neither curl nor wget is available"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
    echo
}

# List current CRDs
list_current_crds() {
    log_step "Listing current ArgoCD CRDs..."
    echo
    
    echo -e "${YELLOW}Current ArgoCD CRDs in cluster:${NC}"
    kubectl get crd | grep -E "(argoproj\.io|argocd)" | while read line; do
        echo "  $line"
    done
    echo
    
    echo -e "${YELLOW}CRD Versions:${NC}"
    kubectl get crd -o custom-columns="NAME:.metadata.name,VERSION:.spec.versions[*].name" | grep -E "(argoproj\.io|argocd)"
    echo
}

# Create backup
create_backup() {
    log_step "Creating backup of current CRDs..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Get all ArgoCD related CRDs
    ARGOCD_CRDS=$(kubectl get crd -o name | grep -E "(argoproj\.io|argocd)" || true)
    
    if [ -z "$ARGOCD_CRDS" ]; then
        log_warning "No ArgoCD CRDs found to backup"
        return
    fi
    
    echo "$ARGOCD_CRDS" | while read crd; do
        crd_name=$(echo $crd | sed 's|customresourcedefinition.apiextensions.k8s.io/||')
        log_info "Backing up CRD: $crd_name"
        kubectl get $crd -o yaml > "$BACKUP_DIR/${crd_name}.yaml"
    done
    
    # Also backup all ArgoCD resources
    log_info "Backing up ArgoCD Application resources..."
    kubectl get applications.argoproj.io -A -o yaml > "$BACKUP_DIR/applications-backup.yaml" 2>/dev/null || true
    kubectl get appprojects.argoproj.io -A -o yaml > "$BACKUP_DIR/appprojects-backup.yaml" 2>/dev/null || true
    kubectl get applicationsets.argoproj.io -A -o yaml > "$BACKUP_DIR/applicationsets-backup.yaml" 2>/dev/null || true
    
    log_success "Backup created in: $BACKUP_DIR"
    echo
}

# Download new CRDs
download_crds() {
    log_step "Downloading ArgoCD CRDs for version $ARGOCD_VERSION..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # List of ArgoCD CRD URLs
    declare -a CRD_URLS=(
        "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/crds/application-crd.yaml"
        "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/crds/applicationset-crd.yaml"
        "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/crds/appproject-crd.yaml"
    )
    
    # Download each CRD
    for url in "${CRD_URLS[@]}"; do
        filename=$(basename "$url")
        log_info "Downloading: $filename"
        
        if command -v curl &> /dev/null; then
            if curl -fsSL "$url" -o "$filename"; then
                log_success "Downloaded: $filename"
            else
                log_error "Failed to download: $filename"
                return 1
            fi
        elif command -v wget &> /dev/null; then
            if wget -q "$url" -O "$filename"; then
                log_success "Downloaded: $filename"
            else
                log_error "Failed to download: $filename"
                return 1
            fi
        fi
    done
    
    echo
    log_success "All CRDs downloaded to: $TEMP_DIR"
    echo
}

# Validate CRDs
validate_crds() {
    log_step "Validating downloaded CRDs..."
    
    cd "$TEMP_DIR"
    
    for file in *.yaml; do
        log_info "Validating: $file"
        
        # Check if file is valid YAML
        if ! kubectl apply --dry-run=client -f "$file" &> /dev/null; then
            log_error "Invalid CRD file: $file"
            return 1
        fi
        
        # Check if it's actually a CRD
        if ! grep -q "kind: CustomResourceDefinition" "$file"; then
            log_error "File is not a CRD: $file"
            return 1
        fi
        
        log_success "Valid: $file"
    done
    
    echo
    log_success "All CRDs validated successfully"
    echo
}

# Show diff
show_crd_diff() {
    log_step "Showing differences between current and new CRDs..."
    echo
    
    cd "$TEMP_DIR"
    
    for file in *.yaml; do
        echo -e "${YELLOW}=== Checking differences for: $file ===${NC}"
        
        # Extract CRD name
        crd_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
        
        # Get current CRD if exists
        if kubectl get crd "$crd_name" &> /dev/null; then
            current_file="/tmp/current-${crd_name}.yaml"
            kubectl get crd "$crd_name" -o yaml > "$current_file"
            
            # Show diff (focusing on spec and version changes)
            echo -e "${CYAN}Version changes:${NC}"
            diff <(grep -A 5 "versions:" "$current_file" 2>/dev/null || echo "No current version") \
                 <(grep -A 5 "versions:" "$file" 2>/dev/null || echo "No new version") || true
            
            echo -e "${CYAN}Schema changes:${NC}"
            diff <(grep -A 10 "openAPIV3Schema:" "$current_file" 2>/dev/null | head -20 || echo "No current schema") \
                 <(grep -A 10 "openAPIV3Schema:" "$file" 2>/dev/null | head -20 || echo "No new schema") || true
            
            rm -f "$current_file"
        else
            echo -e "${GREEN}NEW CRD: $crd_name${NC}"
        fi
        echo
    done
}

# Apply CRDs
apply_crds() {
    log_step "Applying new CRDs..."
    
    cd "$TEMP_DIR"
    
    # Apply each CRD with proper order
    declare -a CRD_FILES=(
        "appproject-crd.yaml"      # Projects first
        "application-crd.yaml"     # Then applications
        "applicationset-crd.yaml"  # Finally applicationsets
    )
    
    for file in "${CRD_FILES[@]}"; do
        if [ -f "$file" ]; then
            log_info "Applying: $file"
            
            if kubectl apply -f "$file"; then
                log_success "Applied: $file"
                
                # Wait for CRD to be established
                crd_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
                log_info "Waiting for CRD to be established: $crd_name"
                kubectl wait --for condition=established --timeout=60s crd/"$crd_name"
                
            else
                log_error "Failed to apply: $file"
                return 1
            fi
        else
            log_warning "File not found: $file"
        fi
    done
    
    echo
    log_success "All CRDs applied successfully"
    echo
}

# Verify ArgoCD resources
verify_resources() {
    log_step "Verifying ArgoCD resources after CRD update..."
    
    echo -e "${YELLOW}Applications status:${NC}"
    kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | wc -l | xargs echo "Total applications:"
    
    echo -e "${YELLOW}Application Projects status:${NC}"
    kubectl get appprojects.argoproj.io -A --no-headers 2>/dev/null | wc -l | xargs echo "Total projects:"
    
    echo -e "${YELLOW}Application Sets status:${NC}"
    kubectl get applicationsets.argoproj.io -A --no-headers 2>/dev/null | wc -l | xargs echo "Total applicationsets:"
    
    echo
    echo -e "${YELLOW}Any problematic resources:${NC}"
    kubectl get applications.argoproj.io -A | grep -E "(Error|Failed|Unknown)" || echo "No problematic applications found"
    
    echo
    log_success "Resource verification completed"
    echo
}

# Restart ArgoCD components
restart_argocd() {
    read -p "Do you want to restart ArgoCD components to pick up CRD changes? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_step "Restarting ArgoCD components..."
        
        # Restart in proper order
        log_info "Restarting application controller..."
        kubectl rollout restart deployment/argocd-application-controller -n $NAMESPACE 2>/dev/null || \
        kubectl rollout restart statefulset/argocd-application-controller -n $NAMESPACE 2>/dev/null || true
        
        log_info "Restarting server..."
        kubectl rollout restart deployment/argocd-server -n $NAMESPACE
        
        log_info "Restarting repo server..."
        kubectl rollout restart deployment/argocd-repo-server -n $NAMESPACE
        
        log_info "Restarting applicationset controller..."
        kubectl rollout restart deployment/argocd-applicationset-controller -n $NAMESPACE 2>/dev/null || true
        
        # Wait for rollouts
        log_info "Waiting for rollouts to complete..."
        kubectl rollout status deployment/argocd-server -n $NAMESPACE --timeout=300s
        kubectl rollout status deployment/argocd-repo-server -n $NAMESPACE --timeout=300s
        
        log_success "ArgoCD components restarted"
    else
        log_info "Skipping ArgoCD restart"
    fi
    echo
}

# Cleanup
cleanup() {
    log_step "Cleaning up temporary files..."
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_success "Temporary directory cleaned: $TEMP_DIR"
    fi
}

# Rollback function
rollback_crds() {
    log_step "Rolling back to previous CRDs..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    cd "$BACKUP_DIR"
    
    for file in *.yaml; do
        if [[ "$file" != *"backup.yaml" ]]; then
            log_info "Restoring CRD: $file"
            kubectl apply -f "$file"
        fi
    done
    
    log_success "Rollback completed"
}

# Main menu
show_menu() {
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1) Full CRD Update (Recommended)"
    echo "2) List Current CRDs Only"
    echo "3) Download and Validate CRDs Only"
    echo "4) Show CRD Differences"
    echo "5) Apply CRDs (if already downloaded)"
    echo "6) Verify Resources After Update"
    echo "7) Rollback to Previous CRDs"
    echo "8) Cleanup and Exit"
    echo
}

# Main function
main() {
    print_header
    check_prerequisites
    
    while true; do
        show_menu
        read -p "Enter your choice [1-8]: " choice
        echo
        
        case $choice in
            1)
                log_info "Starting full CRD update process..."
                list_current_crds
                create_backup
                download_crds
                validate_crds
                show_crd_diff
                
                read -p "Proceed with CRD update? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    apply_crds
                    verify_resources
                    restart_argocd
                    log_success "CRD update completed successfully!"
                else
                    log_info "CRD update cancelled"
                fi
                ;;
            2)
                list_current_crds
                ;;
            3)
                download_crds
                validate_crds
                ;;
            4)
                if [ ! -d "$TEMP_DIR" ]; then
                    download_crds
                fi
                show_crd_diff
                ;;
            5)
                if [ ! -d "$TEMP_DIR" ]; then
                    log_error "CRDs not downloaded. Run option 3 first."
                else
                    apply_crds
                    verify_resources
                fi
                ;;
            6)
                verify_resources
                ;;
            7)
                rollback_crds
                ;;
            8)
                cleanup
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please choose 1-8."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        echo
    done
}

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"