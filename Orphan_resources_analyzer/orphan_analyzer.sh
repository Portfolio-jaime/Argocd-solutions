#!/bin/bash

# =============================================================================
# ArgoCD Orphan Resources Analyzer
# Identifies and analyzes orphaned resources in Kubernetes clusters
# managed by ArgoCD
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE:-argocd}
REPORT_DIR="./orphan_analysis_$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/argocd_orphan_$$"
DRY_RUN=${DRY_RUN:-true}

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

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}    ArgoCD Orphan Resources Analyzer${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}Namespace: ${ARGOCD_NAMESPACE}${NC}"
    echo -e "${BLUE}Report Dir: ${REPORT_DIR}${NC}"
    echo -e "${BLUE}Dry Run: ${DRY_RUN}${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    local deps=("kubectl" "jq" "yq")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    # Check ArgoCD namespace
    if ! kubectl get namespace "$ARGOCD_NAMESPACE" &> /dev/null; then
        log_error "ArgoCD namespace '$ARGOCD_NAMESPACE' not found"
        exit 1
    fi
    
    # Create working directories
    mkdir -p "$REPORT_DIR" "$TEMP_DIR"
    
    log_success "Prerequisites check passed"
}

# Get all ArgoCD managed resources
get_argocd_managed_resources() {
    log_info "Discovering ArgoCD managed resources..."
    
    # Get all applications and their managed resources
    kubectl get applications -A -o json > "$TEMP_DIR/applications.json"
    
    local app_count=$(jq '.items | length' "$TEMP_DIR/applications.json")
    log_info "Found $app_count applications"
    
    # Extract managed resources from all applications
    jq -r '.items[] | 
        select(.status.resources != null) | 
        .metadata.namespace as $appns | 
        .metadata.name as $appname | 
        .status.resources[] | 
        "\($appns)/\($appname),\(.namespace // "default"),\(.kind),\(.name)"' \
        "$TEMP_DIR/applications.json" > "$TEMP_DIR/managed_resources.txt"
    
    local managed_count=$(wc -l < "$TEMP_DIR/managed_resources.txt")
    log_success "Found $managed_count managed resources across all applications"
    
    # Create summary by application
    {
        echo "# ArgoCD Managed Resources Summary"
        echo "Generated: $(date)"
        echo ""
        echo "| Application | Namespace | Resource Count |"
        echo "|-------------|-----------|----------------|"
        
        jq -r '.items[] | 
            select(.status.resources != null) | 
            "\(.metadata.namespace)/\(.metadata.name),\(.status.resources | length)"' \
            "$TEMP_DIR/applications.json" | \
        while IFS=',' read -r app_ref count; do
            echo "| $app_ref | $count |"
        done
    } > "$REPORT_DIR/managed_resources_summary.md"
}

# Get all cluster resources by type
get_cluster_resources() {
    log_info "Scanning cluster resources..."
    
    # Get all resource types
    local resource_types=(
        "pods" "services" "configmaps" "secrets" "persistentvolumeclaims"
        "deployments" "replicasets" "statefulsets" "daemonsets" "jobs" "cronjobs"
        "ingresses" "networkpolicies" "serviceaccounts" "roles" "rolebindings"
        "clusterroles" "clusterrolebindings" "horizontalpodautoscalers"
        "applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io"
    )
    
    echo "# Cluster Resources Inventory" > "$TEMP_DIR/cluster_resources.txt"
    echo "Generated: $(date)" >> "$TEMP_DIR/cluster_resources.txt"
    echo "" >> "$TEMP_DIR/cluster_resources.txt"
    
    for resource_type in "${resource_types[@]}"; do
        log_debug "Scanning $resource_type..."
        
        # Get resources in all namespaces
        kubectl get "$resource_type" -A -o json 2>/dev/null > "$TEMP_DIR/${resource_type}.json" || {
            log_warning "Could not get $resource_type (may not exist in cluster)"
            continue
        }
        
        local count=$(jq '.items | length' "$TEMP_DIR/${resource_type}.json")
        echo "$resource_type: $count" >> "$TEMP_DIR/cluster_resources.txt"
        
        # Extract resource details
        jq -r --arg type "$resource_type" '.items[] | 
            "\(.metadata.namespace // "cluster-scoped"),\($type),\(.metadata.name),\(.metadata.labels // {}),\(.metadata.annotations // {})"' \
            "$TEMP_DIR/${resource_type}.json" >> "$TEMP_DIR/all_resources.txt"
    done
    
    local total_resources=$(wc -l < "$TEMP_DIR/all_resources.txt")
    log_success "Scanned $total_resources total cluster resources"
}

# Analyze orphaned resources
analyze_orphaned_resources() {
    log_info "Analyzing orphaned resources..."
    
    # Create header for orphans report
    {
        echo "# Orphaned Resources Analysis"
        echo "Generated: $(date)"
        echo ""
        echo "Resources found in cluster but not managed by any ArgoCD Application."
        echo ""
        echo "## Summary"
        echo ""
    } > "$REPORT_DIR/orphaned_resources.md"
    
    # Process each cluster resource
    local orphan_count=0
    local managed_count=0
    local excluded_count=0
    
    while IFS=',' read -r namespace kind name labels annotations; do
        # Skip system namespaces and resources
        if [[ "$namespace" =~ ^(kube-system|kube-public|kube-node-lease|default)$ ]]; then
            ((excluded_count++))
            continue
        fi
        
        # Skip ArgoCD's own resources
        if [[ "$namespace" == "$ARGOCD_NAMESPACE" ]]; then
            ((excluded_count++))
            continue
        fi
        
        # Check if resource is managed by ArgoCD
        local is_managed=false
        
        # Method 1: Check against managed resources list
        if grep -q ",$namespace,$kind,$name$" "$TEMP_DIR/managed_resources.txt" 2>/dev/null; then
            is_managed=true
            ((managed_count++))
        fi
        
        # Method 2: Check ArgoCD annotations
        if [[ "$annotations" == *"argocd.argoproj.io/instance"* ]] || 
           [[ "$annotations" == *"argocd.argoproj.io/tracking-id"* ]]; then
            is_managed=true
            if ! grep -q ",$namespace,$kind,$name$" "$TEMP_DIR/managed_resources.txt" 2>/dev/null; then
                ((managed_count++))
            fi
        fi
        
        # If not managed, it's an orphan
        if [ "$is_managed" = false ]; then
            echo "$namespace,$kind,$name,$labels,$annotations" >> "$TEMP_DIR/orphans.txt"
            ((orphan_count++))
        fi
        
    done < "$TEMP_DIR/all_resources.txt"
    
    # Generate orphans summary
    {
        echo "- **Total Resources Scanned**: $(wc -l < "$TEMP_DIR/all_resources.txt")"
        echo "- **ArgoCD Managed**: $managed_count"
        echo "- **Orphaned Resources**: $orphan_count"
        echo "- **System/Excluded**: $excluded_count"
        echo ""
        echo "## Orphaned Resources by Type"
        echo ""
    } >> "$REPORT_DIR/orphaned_resources.md"
    
    if [ -f "$TEMP_DIR/orphans.txt" ] && [ $orphan_count -gt 0 ]; then
        # Group orphans by type
        cut -d',' -f2 "$TEMP_DIR/orphans.txt" | sort | uniq -c | sort -nr | \
        while read -r count type; do
            echo "- **$type**: $count resources"
        done >> "$REPORT_DIR/orphaned_resources.md"
        
        echo "" >> "$REPORT_DIR/orphaned_resources.md"
        echo "## Detailed Orphaned Resources" >> "$REPORT_DIR/orphaned_resources.md"
        echo "" >> "$REPORT_DIR/orphaned_resources.md"
        echo "| Namespace | Kind | Name | Potential Issues |" >> "$REPORT_DIR/orphaned_resources.md"
        echo "|-----------|------|------|------------------|" >> "$REPORT_DIR/orphaned_resources.md"
        
        # Analyze each orphan for potential issues
        while IFS=',' read -r namespace kind name labels annotations; do
            local issues=""
            
            # Check for common orphan patterns
            case "$kind" in
                "ReplicaSet")
                    # Check if parent Deployment exists
                    if [[ "$labels" == *"app="* ]]; then
                        local app_label=$(echo "$labels" | grep -o '"app":"[^"]*"' | cut -d'"' -f4)
                        if ! kubectl get deployment "$app_label" -n "$namespace" &>/dev/null; then
                            issues="Missing parent Deployment"
                        fi
                    fi
                    ;;
                "Pod")
                    # Check if it's a job/deployment pod without parent
                    if [[ "$labels" == *"job-name"* ]]; then
                        local job_name=$(echo "$labels" | grep -o '"job-name":"[^"]*"' | cut -d'"' -f4)
                        if ! kubectl get job "$job_name" -n "$namespace" &>/dev/null; then
                            issues="Missing parent Job"
                        fi
                    fi
                    ;;
                "Service")
                    # Check if service has endpoints
                    if ! kubectl get endpoints "$name" -n "$namespace" &>/dev/null; then
                        issues="No endpoints found"
                    fi
                    ;;
                "ConfigMap"|"Secret")
                    # Check if used by any pods
                    local usage_count=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
                        jq -r --arg name "$name" '.items[] | 
                        select(.spec.volumes[]?.configMap?.name == $name or 
                               .spec.volumes[]?.secret?.secretName == $name or
                               .spec.containers[]?.env[]?.valueFrom?.configMapKeyRef?.name == $name or
                               .spec.containers[]?.env[]?.valueFrom?.secretKeyRef?.name == $name) | 
                        .metadata.name' | wc -l)
                    if [ "$usage_count" -eq 0 ]; then
                        issues="Not referenced by any Pod"
                    fi
                    ;;
            esac
            
            echo "| $namespace | $kind | $name | $issues |" >> "$REPORT_DIR/orphaned_resources.md"
            
        done < "$TEMP_DIR/orphans.txt"
        
    else
        echo "No orphaned resources found! 🎉" >> "$REPORT_DIR/orphaned_resources.md"
    fi
    
    log_success "Orphan analysis complete: $orphan_count orphans found"
}

# Analyze resource dependencies
analyze_dependencies() {
    log_info "Analyzing resource dependencies..."
    
    {
        echo "# Resource Dependencies Analysis"
        echo "Generated: $(date)"
        echo ""
        echo "## Potential Cleanup Candidates"
        echo ""
    } > "$REPORT_DIR/cleanup_candidates.md"
    
    if [ ! -f "$TEMP_DIR/orphans.txt" ]; then
        echo "No orphans to analyze for cleanup." >> "$REPORT_DIR/cleanup_candidates.md"
        return
    fi
    
    # Analyze cleanup safety
    local safe_count=0
    local risky_count=0
    
    echo "| Resource | Namespace | Safety Level | Reason |" >> "$REPORT_DIR/cleanup_candidates.md"
    echo "|----------|-----------|--------------|--------|" >> "$REPORT_DIR/cleanup_candidates.md"
    
    while IFS=',' read -r namespace kind name labels annotations; do
        local safety="UNKNOWN"
        local reason=""
        
        case "$kind" in
            "ConfigMap"|"Secret")
                # Check if it's referenced
                local refs=$(kubectl get pods,deployments,statefulsets -n "$namespace" -o json 2>/dev/null | \
                    jq -r --arg name "$name" --arg kind "$kind" '
                    .items[] | select(
                        (.spec.template.spec.volumes[]?.configMap?.name == $name and $kind == "ConfigMap") or
                        (.spec.template.spec.volumes[]?.secret?.secretName == $name and $kind == "Secret") or
                        (.spec.volumes[]?.configMap?.name == $name and $kind == "ConfigMap") or
                        (.spec.volumes[]?.secret?.secretName == $name and $kind == "Secret") or
                        (.spec.template.spec.containers[]?.env[]?.valueFrom?.configMapKeyRef?.name == $name and $kind == "ConfigMap") or
                        (.spec.template.spec.containers[]?.env[]?.valueFrom?.secretKeyRef?.name == $name and $kind == "Secret") or
                        (.spec.containers[]?.env[]?.valueFrom?.configMapKeyRef?.name == $name and $kind == "ConfigMap") or
                        (.spec.containers[]?.env[]?.valueFrom?.secretKeyRef?.name == $name and $kind == "Secret")
                    ) | .metadata.name' | wc -l)
                
                if [ "$refs" -eq 0 ]; then
                    safety="SAFE"
                    reason="No active references found"
                    ((safe_count++))
                else
                    safety="RISKY"
                    reason="Referenced by $refs resources"
                    ((risky_count++))
                fi
                ;;
                
            "Service")
                # Check if service has active endpoints
                local endpoints=$(kubectl get endpoints "$name" -n "$namespace" -o json 2>/dev/null | \
                    jq -r '.subsets[]?.addresses[]? | length' 2>/dev/null | wc -l)
                
                if [ "$endpoints" -eq 0 ]; then
                    safety="SAFE"
                    reason="No active endpoints"
                    ((safe_count++))
                else
                    safety="RISKY"
                    reason="Has $endpoints active endpoints"
                    ((risky_count++))
                fi
                ;;
                
            "PersistentVolumeClaim")
                # Check if PVC is bound and used
                local pvc_status=$(kubectl get pvc "$name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
                local pod_usage=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
                    jq -r --arg name "$name" '.items[] | 
                    select(.spec.volumes[]?.persistentVolumeClaim?.claimName == $name) | 
                    .metadata.name' | wc -l)
                
                if [ "$pvc_status" = "Bound" ] && [ "$pod_usage" -eq 0 ]; then
                    safety="MODERATE"
                    reason="Bound but unused by pods"
                elif [ "$pvc_status" != "Bound" ]; then
                    safety="SAFE"
                    reason="Not bound to any volume"
                    ((safe_count++))
                else
                    safety="RISKY"
                    reason="Bound and used by $pod_usage pods"
                    ((risky_count++))
                fi
                ;;
                
            "Job")
                # Check job completion and age
                local job_status=$(kubectl get job "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
                local creation_time=$(kubectl get job "$name" -n "$namespace" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
                
                if [ "$job_status" = "True" ]; then
                    safety="SAFE"
                    reason="Job completed successfully"
                    ((safe_count++))
                else
                    safety="MODERATE"
                    reason="Job not completed or failed"
                fi
                ;;
                
            *)
                safety="MODERATE"
                reason="Manual review recommended"
                ;;
        esac
        
        echo "| $kind/$name | $namespace | $safety | $reason |" >> "$REPORT_DIR/cleanup_candidates.md"
        
    done < "$TEMP_DIR/orphans.txt"
    
    {
        echo ""
        echo "## Cleanup Summary"
        echo ""
        echo "- **Safe to Clean**: $safe_count resources"
        echo "- **Risky to Clean**: $risky_count resources"
        echo "- **Need Review**: $(($(wc -l < "$TEMP_DIR/orphans.txt") - safe_count - risky_count)) resources"
        echo ""
        echo "### Safety Levels"
        echo "- **SAFE**: Low risk, likely safe to delete"
        echo "- **MODERATE**: Medium risk, review before deletion"
        echo "- **RISKY**: High risk, careful analysis needed"
    } >> "$REPORT_DIR/cleanup_candidates.md"
    
    log_success "Dependency analysis complete: $safe_count safe, $risky_count risky"
}

# Generate cleanup scripts
generate_cleanup_scripts() {
    log_info "Generating cleanup scripts..."
    
    if [ ! -f "$TEMP_DIR/orphans.txt" ]; then
        log_warning "No orphans found, skipping cleanup script generation"
        return
    fi
    
    # Safe cleanup script
    {
        echo "#!/bin/bash"
        echo "# Generated ArgoCD Orphan Cleanup Script - SAFE RESOURCES ONLY"
        echo "# Generated: $(date)"
        echo ""
        echo "set -e"
        echo ""
        echo "# Colors"
        echo "GREEN='\\033[0;32m'"
        echo "YELLOW='\\033[1;33m'"
        echo "NC='\\033[0m'"
        echo ""
        echo "echo -e \"\${GREEN}Starting safe orphan cleanup...\${NC}\""
        echo ""
    } > "$REPORT_DIR/cleanup_safe.sh"
    
    # Risky cleanup script (commented out)
    {
        echo "#!/bin/bash"
        echo "# Generated ArgoCD Orphan Cleanup Script - ALL RESOURCES (USE WITH CAUTION)"
        echo "# Generated: $(date)"
        echo ""
        echo "set -e"
        echo ""
        echo "# UNCOMMENT LINES BELOW AFTER CAREFUL REVIEW"
        echo "# echo \"This script contains risky deletions. Uncomment to proceed.\""
        echo "# exit 1"
        echo ""
    } > "$REPORT_DIR/cleanup_all.sh"
    
    # Process orphans and generate cleanup commands
    local safe_resources=0
    local risky_resources=0
    
    while IFS=',' read -r namespace kind name labels annotations; do
        local cleanup_cmd="kubectl delete $kind $name -n $namespace"
        
        # Determine if resource is safe to delete
        local is_safe=false
        
        case "$kind" in
            "ConfigMap"|"Secret")
                # Check references (simplified check for script generation)
                local has_refs=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
                    jq -r --arg name "$name" --arg kind "$kind" '
                    .items[] | select(
                        (.spec.volumes[]?.configMap?.name == $name and $kind == "ConfigMap") or
                        (.spec.volumes[]?.secret?.secretName == $name and $kind == "Secret")
                    ) | .metadata.name' | wc -l)
                
                if [ "$has_refs" -eq 0 ]; then
                    is_safe=true
                fi
                ;;
                
            "Job")
                local job_status=$(kubectl get job "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
                if [ "$job_status" = "True" ]; then
                    is_safe=true
                fi
                ;;
        esac
        
        if [ "$is_safe" = true ]; then
            {
                echo "echo -e \"\${YELLOW}Deleting safe resource: $kind/$name in $namespace\${NC}\""
                echo "$cleanup_cmd"
                echo ""
            } >> "$REPORT_DIR/cleanup_safe.sh"
            ((safe_resources++))
        fi
        
        # Add all resources to risky script (commented)
        {
            echo "# echo -e \"\${YELLOW}Deleting resource: $kind/$name in $namespace\${NC}\""
            echo "# $cleanup_cmd"
            echo ""
        } >> "$REPORT_DIR/cleanup_all.sh"
        ((risky_resources++))
        
    done < "$TEMP_DIR/orphans.txt"
    
    # Finalize scripts
    {
        echo "echo -e \"\${GREEN}Safe cleanup completed! Deleted $safe_resources resources.\${NC}\""
        echo "echo -e \"\${YELLOW}Review the full report for more details.\${NC}\""
    } >> "$REPORT_DIR/cleanup_safe.sh"
    
    {
        echo "# echo -e \"\${GREEN}Full cleanup completed! Deleted $risky_resources resources.\${NC}\""
        echo "# echo -e \"\${YELLOW}Review the full report for more details.\${NC}\""
    } >> "$REPORT_DIR/cleanup_all.sh"
    
    # Make scripts executable
    chmod +x "$REPORT_DIR/cleanup_safe.sh" "$REPORT_DIR/cleanup_all.sh"
    
    log_success "Generated cleanup scripts: $safe_resources safe, $risky_resources total resources"
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive report..."
    
    {
        echo "# ArgoCD Orphan Resources Analysis Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Executive Summary"
        echo ""
        
        local total_orphans=0
        if [ -f "$TEMP_DIR/orphans.txt" ]; then
            total_orphans=$(wc -l < "$TEMP_DIR/orphans.txt")
        fi
        
        local total_managed=0
        if [ -f "$TEMP_DIR/managed_resources.txt" ]; then
            total_managed=$(wc -l < "$TEMP_DIR/managed_resources.txt")
        fi
        
        local total_scanned=0
        if [ -f "$TEMP_DIR/all_resources.txt" ]; then
            total_scanned=$(wc -l < "$TEMP_DIR/all_resources.txt")
        fi
        
        echo "- **Total Resources Scanned**: $total_scanned"
        echo "- **ArgoCD Managed Resources**: $total_managed"
        echo "- **Orphaned Resources Found**: $total_orphans"
        echo "- **Orphan Percentage**: $(( total_orphans * 100 / (total_scanned > 0 ? total_scanned : 1) ))%"
        echo ""
        
        if [ $total_orphans -eq 0 ]; then
            echo "🎉 **Excellent!** No orphaned resources found in your cluster."
            echo ""
            echo "Your ArgoCD setup appears to be well-maintained with all resources properly managed."
        elif [ $total_orphans -lt 10 ]; then
            echo "✅ **Good!** Only a few orphaned resources found."
            echo ""
            echo "This is normal for active clusters. Review the cleanup recommendations below."
        elif [ $total_orphans -lt 50 ]; then
            echo "⚠️ **Moderate** number of orphaned resources found."
            echo ""
            echo "Consider regular cleanup maintenance to keep your cluster tidy."
        else
            echo "🚨 **High** number of orphaned resources found."
            echo ""
            echo "Immediate attention recommended to prevent resource waste and potential issues."
        fi
        
        echo ""
        echo "## Report Files Generated"
        echo ""
        echo "- \`orphaned_resources.md\` - Detailed orphan analysis"
        echo "- \`cleanup_candidates.md\` - Cleanup safety analysis"
        echo "- \`managed_resources_summary.md\` - ArgoCD managed resources"
        echo "- \`cleanup_safe.sh\` - Safe cleanup script"
        echo "- \`cleanup_all.sh\` - Full cleanup script (use with caution)"
        echo ""
        echo "## Recommendations"
        echo ""
        
        if [ $total_orphans -gt 0 ]; then
            echo "1. **Review** the orphaned resources in \`orphaned_resources.md\`"
            echo "2. **Analyze** cleanup safety in \`cleanup_candidates.md\`"
            echo "3. **Execute** safe cleanup with \`./cleanup_safe.sh\`"
            echo "4. **Manually review** risky resources before cleanup"
            echo "5. **Schedule** regular orphan analysis (weekly/monthly)"
        else
            echo "1. **Maintain** current good practices"
            echo "2. **Schedule** periodic orphan analysis"
            echo "3. **Monitor** new deployments for proper ArgoCD management"
        fi
        
        echo ""
        echo "## Next Steps"
        echo ""
        echo "- Set up automated orphan detection"
        echo "- Implement resource naming conventions"
        echo "- Create cleanup policies and procedures"
        echo "- Train team on ArgoCD resource management"
        
    } > "$REPORT_DIR/README.md"
    
    log_success "Comprehensive report generated in $REPORT_DIR/"
}

# Cleanup temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    log_success "Cleanup completed"
}

# Main execution flow
main() {
    print_header
    
    trap cleanup EXIT ERR
    
    check_prerequisites
    get_argocd_managed_resources
    get_cluster_resources
    analyze_orphaned_resources
    analyze_dependencies
    generate_cleanup_scripts
    generate_report
    
    echo
    log_success "Orphan analysis completed successfully!"
    log_info "Report available in: $REPORT_DIR/"
    echo
    echo -e "${CYAN}To view the report:${NC}"
    echo "  cat $REPORT_DIR/README.md"
    echo ""
    echo -e "${CYAN}To run safe cleanup:${NC}"
    echo "  $REPORT_DIR/cleanup_safe.sh"
    echo ""
    echo -e "${YELLOW}Always review before running cleanup scripts!${NC}"
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi