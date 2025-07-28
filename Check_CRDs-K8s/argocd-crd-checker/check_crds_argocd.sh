#!/bin/bash

# ArgoCD CRDs Compatibility Checker - Refactored Version
# Author: Security Analysis Tool
# Version: 2.0
# Description: Enhanced script for checking ArgoCD CRD compatibility in EKS clusters

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_DEPENDENCY_MISSING=2
readonly EXIT_KUBECTL_ERROR=3
readonly EXIT_COMPATIBILITY_ISSUES=4
readonly EXIT_GENERAL_ERROR=5

# Configuration defaults
DEFAULT_NAMESPACE="argocd"
DEFAULT_TIMEOUT=30
DEFAULT_OUTPUT_FORMAT="table"
SCRIPT_VERSION="2.0"

# Global configuration
NAMESPACE="$DEFAULT_NAMESPACE"
TIMEOUT="$DEFAULT_TIMEOUT"
OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
VERBOSE=false
DRY_RUN=false
EXPORT_FILE=""
LOG_FILE=""

# Colors and icons
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly NC='\033[0m'
    readonly BOLD='\033[1m'
    
    readonly CHECK="✅"
    readonly WARNING="⚠️"
    readonly ERROR="❌"
    readonly INFO="ℹ️"
    readonly GEAR="⚙️"
    readonly CHART="📊"
    readonly VERSION="🏷️"
    readonly COMPATIBLE="✨"
    readonly INCOMPATIBLE="💥"
    readonly ROCKET="🚀"
    readonly CLUSTER="🏗️"
    readonly UPDATE="🔄"
    readonly SECURITY="🔒"
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly PURPLE=''
    readonly CYAN=''
    readonly WHITE=''
    readonly NC=''
    readonly BOLD=''
    
    readonly CHECK="[OK]"
    readonly WARNING="[WARN]"
    readonly ERROR="[ERROR]"
    readonly INFO="[INFO]"
    readonly GEAR="[CONFIG]"
    readonly CHART="[CHART]"
    readonly VERSION="[VER]"
    readonly COMPATIBLE="[COMPAT]"
    readonly INCOMPATIBLE="[INCOMPAT]"
    readonly ROCKET="[ACTION]"
    readonly CLUSTER="[CLUSTER]"
    readonly UPDATE="[UPDATE]"
    readonly SECURITY="[SEC]"
fi

# Cache for expensive operations (use simpler approach for compatibility)
COMMAND_CACHE_DIR="/tmp/argocd_checker_cache_$$"
mkdir -p "$COMMAND_CACHE_DIR" 2>/dev/null || true

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    if [[ "$VERBOSE" == "true" ]] || [[ "$level" == "ERROR" ]]; then
        case "$level" in
            "ERROR") echo -e "${RED}${ERROR} $message${NC}" >&2 ;;
            "WARN")  echo -e "${YELLOW}${WARNING} $message${NC}" >&2 ;;
            "INFO")  echo -e "${BLUE}${INFO} $message${NC}" ;;
            "DEBUG") [[ "$VERBOSE" == "true" ]] && echo -e "${PURPLE}[DEBUG] $message${NC}" ;;
        esac
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Script failed at line $line_number with exit code $exit_code"
    cleanup
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Cleanup function
cleanup() {
    log "DEBUG" "Performing cleanup..."
    # Remove cache directory
    [[ -d "$COMMAND_CACHE_DIR" ]] && rm -rf "$COMMAND_CACHE_DIR" 2>/dev/null || true
}

# Show usage information
show_usage() {
    cat << EOF
ArgoCD CRDs Compatibility Checker v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    ArgoCD namespace (default: $DEFAULT_NAMESPACE)
    -t, --timeout SECONDS        Command timeout (default: $DEFAULT_TIMEOUT)
    -o, --output FORMAT          Output format: table, json, csv (default: $DEFAULT_OUTPUT_FORMAT)
    -e, --export FILE            Export results to file
    -l, --log FILE               Enable logging to file
    -v, --verbose                Enable verbose output
    -d, --dry-run                Show what would be done without executing
    -h, --help                   Show this help message
    --version                    Show version information

EXAMPLES:
    $0                                          # Basic check with defaults
    $0 -n my-argocd -v                         # Check custom namespace with verbose output
    $0 -o json -e results.json                 # Export results to JSON file
    $0 --dry-run -l check.log                  # Dry run with logging

EXIT CODES:
    0 - Success
    1 - Invalid arguments
    2 - Missing dependencies
    3 - Kubectl/Kubernetes error
    4 - Compatibility issues found
    5 - General error
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -t|--timeout)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    TIMEOUT="$2"
                else
                    log "ERROR" "Invalid timeout value: $2"
                    exit $EXIT_INVALID_ARGS
                fi
                shift 2
                ;;
            -o|--output)
                case "$2" in
                    table|json|csv)
                        OUTPUT_FORMAT="$2"
                        ;;
                    *)
                        log "ERROR" "Invalid output format: $2. Use: table, json, csv"
                        exit $EXIT_INVALID_ARGS
                        ;;
                esac
                shift 2
                ;;
            -e|--export)
                EXPORT_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit $EXIT_SUCCESS
                ;;
            --version)
                echo "ArgoCD CRDs Compatibility Checker v$SCRIPT_VERSION"
                exit $EXIT_SUCCESS
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done
}

# Check required dependencies
check_dependencies() {
    log "DEBUG" "Checking dependencies..."
    
    local missing_deps=()
    local optional_deps=()
    
    # Required dependencies
    for cmd in kubectl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Optional dependencies
    for cmd in helm jq aws python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            optional_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "ERROR" "Please install the missing tools and try again"
        exit $EXIT_DEPENDENCY_MISSING
    fi
    
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log "WARN" "Optional dependencies missing: ${optional_deps[*]}"
        log "WARN" "Some features may be limited"
    fi
    
    log "DEBUG" "Dependencies check completed"
}

# Execute kubectl command with timeout and caching
kubectl_with_timeout() {
    local cmd="$*"
    local cache_key
    cache_key=$(echo "$cmd" | md5sum 2>/dev/null | cut -d' ' -f1 2>/dev/null || echo "${cmd// /_}")
    local cache_file="$COMMAND_CACHE_DIR/$cache_key"
    
    # Check cache first
    if [[ -f "$cache_file" ]]; then
        log "DEBUG" "Using cached result for: $cmd"
        cat "$cache_file"
        return 0
    fi
    
    log "DEBUG" "Executing: kubectl $cmd"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would execute: kubectl $cmd"
        return 0
    fi
    
    local result
    if result=$(timeout "$TIMEOUT" kubectl $cmd 2>/dev/null); then
        echo "$result" | tee "$cache_file"
        return 0
    else
        local exit_code=$?
        log "ERROR" "kubectl command failed: kubectl $cmd (exit code: $exit_code)"
        return $exit_code
    fi
}

# Cross-platform version comparison
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Remove 'v' prefix if present
    version1=${version1#v}
    version2=${version2#v}
    
    # Simple version comparison using sort
    if command -v sort >/dev/null 2>&1; then
        local sorted_versions
        sorted_versions=$(printf '%s\n%s\n' "$version1" "$version2" | sort -V 2>/dev/null || sort -t. -k1,1n -k2,2n -k3,3n)
        local first_version
        first_version=$(echo "$sorted_versions" | head -n1)
        
        [[ "$first_version" == "$version2" ]]
    else
        # Fallback for systems without sort -V
        python3 -c "
import sys
from packaging import version
try:
    result = version.parse('$version1') >= version.parse('$version2')
    sys.exit(0 if result else 1)
except:
    sys.exit(2)
" 2>/dev/null
    fi
}

# Get cluster information with improved error handling
get_cluster_info() {
    log "DEBUG" "Gathering cluster information..."
    
    local cluster_name=""
    local k8s_version=""
    local region=""
    local context=""
    
    # Get current context
    if context=$(kubectl_with_timeout "config current-context"); then
        log "DEBUG" "Current context: $context"
        
        # Try to extract EKS information
        if [[ "$context" == *"eks"* ]] && command -v aws >/dev/null 2>&1; then
            cluster_name=$(echo "$context" | grep -o '[^/]*$' || echo "")
            region=$(echo "$context" | grep -o 'arn:aws:eks:[^:]*' | cut -d':' -f4 2>/dev/null || echo "")
        fi
    else
        log "WARN" "Could not determine current context"
        context="Unknown"
    fi
    
    # Get Kubernetes version with multiple fallbacks
    if k8s_version=$(kubectl_with_timeout "version --output=json" | jq -r '.serverVersion.gitVersion' 2>/dev/null); then
        log "DEBUG" "Kubernetes version (JSON): $k8s_version"
    elif k8s_version=$(kubectl_with_timeout "version --short" | grep "Server Version" | cut -d' ' -f3 2>/dev/null); then
        log "DEBUG" "Kubernetes version (short): $k8s_version"
    else
        log "WARN" "Could not determine Kubernetes version"
        k8s_version="Unknown"
    fi
    
    echo "${cluster_name:-Unknown}|${k8s_version}|${region:-Unknown}|${context}"
}

# Get ArgoCD installation information
get_argocd_info() {
    log "DEBUG" "Gathering ArgoCD installation information..."
    
    local helm_release=""
    local chart_version=""
    local image_version=""
    local argocd_image=""
    local helm_app_version=""
    
    # Check if namespace exists
    if ! kubectl_with_timeout "get namespace $NAMESPACE" >/dev/null; then
        log "ERROR" "Namespace '$NAMESPACE' not found"
        return $EXIT_KUBECTL_ERROR
    fi
    
    # Get Helm information if available
    if command -v helm >/dev/null 2>&1; then
        local helm_info
        if helm_info=$(timeout "$TIMEOUT" helm list -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.[] | select(.name | test("argo")) | "\(.name)|\(.chart)|\(.app_version)"' 2>/dev/null | head -1); then
            if [[ -n "$helm_info" ]]; then
                helm_release=$(echo "$helm_info" | cut -d'|' -f1)
                chart_version=$(echo "$helm_info" | cut -d'|' -f2)
                helm_app_version=$(echo "$helm_info" | cut -d'|' -f3)
                log "DEBUG" "Helm release found: $helm_release"
            fi
        fi
    fi
    
    # Get ArgoCD server image
    if argocd_image=$(kubectl_with_timeout "get pods -n $NAMESPACE -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.containers[0].image}'"); then
        if [[ -n "$argocd_image" ]]; then
            image_version=$(echo "$argocd_image" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
            log "DEBUG" "ArgoCD image: $argocd_image"
        fi
    fi
    
    echo "${helm_release}|${chart_version}|${helm_app_version}|${argocd_image}|${image_version}"
}

# Analyze CRD compatibility with improved efficiency
analyze_crd_compatibility() {
    log "DEBUG" "Analyzing CRD compatibility..."
    
    local argocd_version="$1"
    local argocd_crds=("applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io")
    local rollouts_crds=("rollouts.argoproj.io" "analysisruns.argoproj.io" "analysistemplates.argoproj.io" "experiments.argoproj.io" "clusteranalysistemplates.argoproj.io")
    
    # Get all CRDs in one call for efficiency
    local all_crds
    if ! all_crds=$(kubectl_with_timeout "get crd -o json"); then
        log "ERROR" "Failed to retrieve CRDs"
        return $EXIT_KUBECTL_ERROR
    fi
    
    # Analyze ArgoCD CRDs
    local crd_results=()
    local issues_found=false
    
    for crd in "${argocd_crds[@]}"; do
        local crd_info
        if crd_info=$(echo "$all_crds" | jq -r --arg crd "$crd" '.items[] | select(.metadata.name == $crd) | "\(.spec.versions[].name | @csv)|\(.metadata.creationTimestamp)"' 2>/dev/null); then
            if [[ -n "$crd_info" ]]; then
                local versions creation_date
                versions=$(echo "$crd_info" | cut -d'|' -f1 | tr -d '"' | tr ',' ' ')
                creation_date=$(echo "$crd_info" | cut -d'|' -f2 | cut -d'T' -f1)
                
                local compatibility_result
                compatibility_result=$(check_detailed_crd_compatibility "$argocd_version" "$crd" "$versions" "$creation_date")
                
                local status action reason
                status=$(echo "$compatibility_result" | cut -d'|' -f1)
                action=$(echo "$compatibility_result" | cut -d'|' -f2)
                reason=$(echo "$compatibility_result" | cut -d'|' -f3)
                
                crd_results+=("$crd|$versions|$status|$creation_date|$action|$reason")
                
                if [[ "$action" != "OK" ]]; then
                    issues_found=true
                fi
            else
                crd_results+=("$crd|MISSING|${ERROR} Not found|N/A|CRITICAL|CRD completely missing")
                issues_found=true
            fi
        else
            crd_results+=("$crd|MISSING|${ERROR} Not found|N/A|CRITICAL|CRD completely missing")
            issues_found=true
        fi
    done
    
    # Output results based on format
    case "$OUTPUT_FORMAT" in
        "json")
            output_json_results "${crd_results[@]}"
            ;;
        "csv")
            output_csv_results "${crd_results[@]}"
            ;;
        *)
            output_table_results "${crd_results[@]}"
            ;;
    esac
    
    if [[ "$issues_found" == "true" ]]; then
        return $EXIT_COMPATIBILITY_ISSUES
    fi
    
    return $EXIT_SUCCESS
}

# Check detailed CRD compatibility
check_detailed_crd_compatibility() {
    local argocd_version="$1"
    local crd_name="$2"
    local crd_versions="$3"
    local crd_creation_date="$4"
    
    case "$crd_name" in
        "applications.argoproj.io")
            if [[ "$crd_versions" == *"v1beta1"* ]] && [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${GREEN}${COMPATIBLE} Compatible completo${NC}|OK|Soporta ambas APIs necesarias"
            elif [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${YELLOW}${WARNING} Requiere actualización${NC}|ACTUALIZAR|Falta soporte v1beta1 - Argo CD 2.5+ requiere esta API"
            else
                echo "${RED}${INCOMPATIBLE} Incompatible${NC}|CRÍTICO|CRD corrupto o versión muy antigua"
            fi
            ;;
        "applicationsets.argoproj.io")
            if [[ "$crd_versions" == *"v1alpha1"* ]] && [[ -n "$argocd_version" ]] && version_compare "$argocd_version" "v2.3.0"; then
                echo "${GREEN}${COMPATIBLE} Compatible${NC}|OK|ApplicationSets funcional"
            elif [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${YELLOW}${WARNING} Versión Argo CD antigua${NC}|ACTUALIZAR|ApplicationSets requiere Argo CD >= 2.3.0"
            else
                echo "${RED}${INCOMPATIBLE} CRD faltante${NC}|CRÍTICO|ApplicationSets no funcionará"
            fi
            ;;
        "appprojects.argoproj.io")
            if [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${GREEN}${COMPATIBLE} Compatible${NC}|OK|Projects funcionando correctamente"
            else
                echo "${RED}${INCOMPATIBLE} CRD faltante${NC}|CRÍTICO|RBAC de proyectos no funcionará"
            fi
            ;;
        *)
            echo "${YELLOW}${WARNING} Desconocido${NC}|UNKNOWN|CRD no reconocido"
            ;;
    esac
}

# Output functions for different formats
output_table_results() {
    local results=("$@")
    
    print_header "${GEAR} ANÁLISIS COMPLETO CRDs ARGO CD"
    
    # Get all information first (to avoid mixed output)
    local cluster_info argocd_info
    cluster_info=$(get_cluster_info 2>/dev/null)
    argocd_info=$(get_argocd_info 2>/dev/null)
    
    # Show cluster info first
    display_cluster_info "$cluster_info"
    
    # Show ArgoCD installation info
    display_argocd_info "$argocd_info"
    
    echo ""
    print_table_header "ANÁLISIS DETALLADO DE COMPATIBILIDAD"
    
    # Table header with better spacing
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}CRD                 ${NC} ${BOLD}${CYAN}│${NC} ${BOLD}Versiones API  ${NC} ${BOLD}${CYAN}│${NC} ${BOLD}Estado              ${NC} ${BOLD}${CYAN}│${NC} ${BOLD}Fecha       ${NC} ${BOLD}${CYAN}│${NC}"
    print_table_separator
    
    for result in "${results[@]}"; do
        IFS='|' read -r crd versions status date action reason <<< "$result"
        local crd_short
        crd_short=$(echo "$crd" | sed 's/.argoproj.io//')
        
        # Truncate long versions if needed
        local display_versions="$versions"
        if [[ ${#versions} -gt 15 ]]; then
            display_versions="${versions:0:12}..."
        fi
        
        # Pad fields to ensure alignment
        local padded_crd
        padded_crd=$(printf "%-20s" "$crd_short")
        local padded_versions
        padded_versions=$(printf "%-15s" "$display_versions")
        local padded_date
        padded_date=$(printf "%-12s" "$date")
        
        echo -e "${BOLD}${CYAN}│${NC} $padded_crd ${BOLD}${CYAN}│${NC} $padded_versions ${BOLD}${CYAN}│${NC} $status ${BOLD}${CYAN}│${NC} $padded_date ${BOLD}${CYAN}│${NC}"
    done
    
    print_table_footer
    
    # Show issues summary if any
    display_issues_summary "${results[@]}"
}

output_json_results() {
    local results=("$@")
    local json_output='{"timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","crds":['
    
    local first=true
    for result in "${results[@]}"; do
        IFS='|' read -r crd versions status date action reason <<< "$result"
        
        if [[ "$first" != "true" ]]; then
            json_output+=","
        fi
        first=false
        
        json_output+="{\"name\":\"$crd\",\"versions\":\"$versions\",\"status\":\"$action\",\"date\":\"$date\",\"reason\":\"$reason\"}"
    done
    
    json_output+=']}'
    
    echo "$json_output"
}

output_csv_results() {
    local results=("$@")
    
    echo "CRD,Versions,Status,Date,Action,Reason"
    for result in "${results[@]}"; do
        IFS='|' read -r crd versions status date action reason <<< "$result"
        echo "\"$crd\",\"$versions\",\"$action\",\"$date\",\"$reason\""
    done
}

# Utility functions for table formatting
print_header() {
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        echo ""
        local header_text="$1"
        local header_length=80
        local padding=$(( (header_length - ${#header_text} - 2) / 2 ))
        
        echo -e "${BOLD}${BLUE}$(printf '═%.0s' $(seq 1 $header_length))${NC}"
        printf "${BOLD}${BLUE}%*s${WHITE} %s ${BLUE}%*s${NC}\n" $padding "" "$header_text" $padding ""
        echo -e "${BOLD}${BLUE}$(printf '═%.0s' $(seq 1 $header_length))${NC}"
        echo ""
    fi
}

print_table_header() {
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        local title="$1"
        local table_width=80
        local title_padding=$(( (table_width - ${#title} - 2) / 2 ))
        
        echo -e "${BOLD}${CYAN}┌$(printf '─%.0s' $(seq 1 $((table_width-2))))┐${NC}"
        printf "${BOLD}${CYAN}│${WHITE}%*s %s %*s${CYAN}│${NC}\n" $title_padding "" "$title" $title_padding ""
        echo -e "${BOLD}${CYAN}├$(printf '─%.0s' $(seq 1 $((table_width-2))))┤${NC}"
    fi
}

print_table_footer() {
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        local table_width=80
        echo -e "${BOLD}${CYAN}└$(printf '─%.0s' $(seq 1 $((table_width-2))))┘${NC}"
    fi
}

print_table_separator() {
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        local table_width=80
        echo -e "${BOLD}${CYAN}├$(printf '─%.0s' $(seq 1 $((table_width-2))))┤${NC}"
    fi
}

# Display cluster information in a nice format
display_cluster_info() {
    if [[ "$OUTPUT_FORMAT" != "table" ]]; then
        return
    fi
    
    local cluster_info="$1"
    local cluster_name k8s_version region context
    
    IFS='|' read -r cluster_name k8s_version region context <<< "$cluster_info"
    
    print_table_header "INFORMACIÓN DEL CLUSTER"
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}Cluster EKS:   ${NC} ${BOLD}${CYAN}│${NC} ${GREEN}${cluster_name}${NC}"
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}Kubernetes:    ${NC} ${BOLD}${CYAN}│${NC} ${BLUE}${k8s_version}${NC}"
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}Región AWS:    ${NC} ${BOLD}${CYAN}│${NC} ${PURPLE}${region}${NC}"
    
    # Truncate long context for display
    local display_context="$context"
    if [[ ${#context} -gt 55 ]]; then
        display_context="...${context: -52}"
    fi
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}Contexto:      ${NC} ${BOLD}${CYAN}│${NC} ${YELLOW}${display_context}${NC}"
    print_table_footer
}

# Display issues summary
display_issues_summary() {
    local results=("$@")
    local issues_found=()
    
    for result in "${results[@]}"; do
        IFS='|' read -r crd versions status date action reason <<< "$result"
        if [[ "$action" != "OK" ]]; then
            issues_found+=("$result")
        fi
    done
    
    if [[ ${#issues_found[@]} -gt 0 ]]; then
        echo ""
        print_table_header "PROBLEMAS DETECTADOS Y SOLUCIONES"
        
        for issue in "${issues_found[@]}"; do
            IFS='|' read -r crd versions status date action reason <<< "$issue"
            local crd_short
            crd_short=$(echo "$crd" | sed 's/.argoproj.io//')
            
            echo -e "${BOLD}${CYAN}│${NC}"
            case "$action" in
                "ACTUALIZAR")
                    echo -e "${BOLD}${CYAN}│${NC} ${YELLOW}${WARNING} $crd_short: $reason"
                    echo -e "${BOLD}${CYAN}│${NC} ${INFO} Solución: Actualizar CRDs antes que la aplicación"
                    ;;
                "CRÍTICO"|"CRITICAL")
                    echo -e "${BOLD}${CYAN}│${NC} ${RED}${ERROR} $crd_short: $reason"
                    echo -e "${BOLD}${CYAN}│${NC} ${INFO} Solución: Reinstalar CRDs inmediatamente"
                    ;;
            esac
            echo -e "${BOLD}${CYAN}│${NC}"
        done
        
        print_table_footer
    fi
}

# Display ArgoCD installation information
display_argocd_info() {
    if [[ "$OUTPUT_FORMAT" != "table" ]]; then
        return
    fi
    
    local argocd_info="$1"
    local helm_release chart_version helm_app_version argocd_image image_version
    
    IFS='|' read -r helm_release chart_version helm_app_version argocd_image image_version <<< "$argocd_info"
    
    echo ""
    print_table_header "INSTALACIÓN ARGO CD"
    
    if [[ -n "$helm_release" ]]; then
        echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${CHART} Helm Release: ${NC} ${BOLD}${CYAN}│${NC} ${GREEN}$helm_release${NC}"
        echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${VERSION} Chart Version:${NC} ${BOLD}${CYAN}│${NC} ${GREEN}$chart_version${NC}"
        [[ -n "$helm_app_version" ]] && echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${VERSION} App Version:  ${NC} ${BOLD}${CYAN}│${NC} ${GREEN}$helm_app_version${NC}"
    else
        echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${WARNING} Instalación:   ${NC} ${BOLD}${CYAN}│${NC} ${YELLOW}Manual (No Helm)${NC}"
    fi
    
    if [[ -n "$argocd_image" ]]; then
        local display_image="$argocd_image"
        if [[ ${#argocd_image} -gt 50 ]]; then
            display_image="...${argocd_image: -47}"
        fi
        echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${GEAR} Imagen:        ${NC} ${BOLD}${CYAN}│${NC} ${BLUE}$display_image${NC}"
    fi
    
    if [[ -n "$image_version" ]]; then
        echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${VERSION} Versión:       ${NC} ${BOLD}${CYAN}│${NC} ${GREEN}$image_version${NC}"
    else
        echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${ERROR} Versión:       ${NC} ${BOLD}${CYAN}│${NC} ${RED}No detectada${NC}"
    fi
    
    print_table_footer
}

# Generate update recommendations
generate_update_recommendations() {
    local argocd_version="$1"
    local chart_version="$2"
    local helm_release="$3"
    
    if [[ "$OUTPUT_FORMAT" != "table" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}${PURPLE}${ROCKET} PLAN DE ACTUALIZACIÓN RECOMENDADO:${NC}"
    echo ""
    
    # Check for latest versions if helm is available
    if command -v helm >/dev/null 2>&1; then
        local latest_chart latest_app
        if latest_chart=$(timeout "$TIMEOUT" helm search repo argo/argo-cd --output json 2>/dev/null | jq -r '.[0].version' 2>/dev/null); then
            latest_app=$(timeout "$TIMEOUT" helm search repo argo/argo-cd --output json 2>/dev/null | jq -r '.[0].app_version' 2>/dev/null)
            
            echo -e "${INFO} ${BOLD}Versiones disponibles:${NC}"
            echo -e "  • Chart más reciente: ${GREEN}${latest_chart:-"No disponible"}${NC}"
            echo -e "  • App más reciente: ${GREEN}${latest_app:-"No disponible"}${NC}"
            echo -e "  • Tu Chart actual: ${BLUE}$chart_version${NC}"
            echo -e "  • Tu App actual: ${BLUE}$argocd_version${NC}"
            echo ""
        fi
    fi
    
    print_table_header "PLAN DE ACTUALIZACIÓN RECOMENDADO"
    
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${YELLOW}1. PRE-ACTUALIZACIÓN (CRÍTICO):${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${WARNING} Realizar backup de aplicaciones:"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}kubectl get applications -n $NAMESPACE -o yaml > backup-applications.yaml${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}kubectl get appprojects -n $NAMESPACE -o yaml > backup-projects.yaml${NC}"
    echo -e "${BOLD}${CYAN}│${NC}"
    
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${BLUE}2. ACTUALIZACIÓN DE CRDs:${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${INFO} Los CRDs deben actualizarse ANTES que la aplicación:"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}# Usar versión específica en lugar de 'stable'${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}ARGOCD_VERSION=\"v2.8.0\"  # Especificar versión objetivo${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/\$ARGOCD_VERSION/manifests/crds/application-crd.yaml${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/\$ARGOCD_VERSION/manifests/crds/applicationset-crd.yaml${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/\$ARGOCD_VERSION/manifests/crds/appproject-crd.yaml${NC}"
    echo -e "${BOLD}${CYAN}│${NC}"
    
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${GREEN}3. ACTUALIZACIÓN VIA HELM:${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}helm repo update${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}helm upgrade $helm_release argo/argo-cd -n $NAMESPACE \\${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}    --reuse-values \\${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${BLUE}    --wait --timeout=600s${NC}"
    echo -e "${BOLD}${CYAN}│${NC}"
    
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${PURPLE}4. POST-ACTUALIZACIÓN:${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${INFO} Verificar pods: ${BLUE}kubectl get pods -n $NAMESPACE${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${INFO} Verificar aplicaciones: ${BLUE}kubectl get applications -n $NAMESPACE${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${INFO} Re-ejecutar este script para verificar compatibilidad"
    echo -e "${BOLD}${CYAN}│${NC}"
    
    echo -e "${BOLD}${CYAN}│${NC} ${BOLD}${RED}5. CONSIDERACIONES EKS:${NC}"
    echo -e "${BOLD}${CYAN}│${NC}   ${WARNING} Verificar compatibilidad con versión de K8s"
    echo -e "${BOLD}${CYAN}│${NC}   ${WARNING} Los CRDs se almacenan en etcd - hacer backup si es crítico"
    echo -e "${BOLD}${CYAN}│${NC}   ${WARNING} Rollback disponible con: ${BLUE}helm rollback $helm_release${NC}"
    
    print_table_footer
}

# Generate final summary
generate_final_summary() {
    local analysis_result="$1"
    local argocd_version="$2"
    
    echo ""
    print_header "${CHART} RESUMEN EJECUTIVO"
    
    print_table_header "ESTADO GENERAL DEL SISTEMA"
    
    if [[ -n "$argocd_version" ]]; then
        echo -e "${BOLD}${CYAN}│${NC} ${GREEN}${CHECK} ArgoCD detectado: ${BOLD}$argocd_version${NC}"
        
        if version_compare "$argocd_version" "v2.8.0"; then
            echo -e "${BOLD}${CYAN}│${NC} ${GREEN}${CHECK} Versión actual y bien soportada${NC}"
        elif version_compare "$argocd_version" "v2.4.0"; then
            echo -e "${BOLD}${CYAN}│${NC} ${YELLOW}${WARNING} Versión funcional - considerar actualización${NC}"
        else
            echo -e "${BOLD}${CYAN}│${NC} ${RED}${ERROR} Versión antigua - actualización recomendada${NC}"
        fi
    else
        echo -e "${BOLD}${CYAN}│${NC} ${RED}${ERROR} No se pudo determinar la versión de ArgoCD${NC}"
    fi
    
    echo -e "${BOLD}${CYAN}│${NC}"
    
    case "$analysis_result" in
        "$EXIT_SUCCESS")
            echo -e "${BOLD}${CYAN}│${NC} ${GREEN}${CHECK} Todos los CRDs son compatibles${NC}"
            echo -e "${BOLD}${CYAN}│${NC} ${GREEN}${CHECK} Sistema listo para producción${NC}"
            ;;
        "$EXIT_COMPATIBILITY_ISSUES")
            echo -e "${BOLD}${CYAN}│${NC} ${RED}${ERROR} Se encontraron problemas de compatibilidad${NC}"
            echo -e "${BOLD}${CYAN}│${NC} ${WARNING} ${BOLD}Acción requerida antes de continuar${NC}"
            ;;
        *)
            echo -e "${BOLD}${CYAN}│${NC} ${YELLOW}${WARNING} Verificación incompleta${NC}"
            ;;
    esac
    
    print_table_footer
    
    # Next steps
    echo ""
    print_table_header "PRÓXIMOS PASOS RECOMENDADOS"
    echo -e "${BOLD}${CYAN}│${NC} ${INFO} 1. Ejecutar este script después de cada actualización"
    echo -e "${BOLD}${CYAN}│${NC} ${INFO} 2. Mantener un calendario de actualizaciones regulares"
    echo -e "${BOLD}${CYAN}│${NC} ${INFO} 3. Monitorear logs de ArgoCD después de cambios"
    echo -e "${BOLD}${CYAN}│${NC} ${INFO} 4. Considerar automatizar el proceso de actualización"
    print_table_footer
}

# Main execution function
main() {
    log "INFO" "Starting ArgoCD CRDs Compatibility Checker v$SCRIPT_VERSION"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Initialize logging
    if [[ -n "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || {
            log "ERROR" "Cannot create log file: $LOG_FILE"
            exit $EXIT_GENERAL_ERROR
        }
        log "INFO" "Logging enabled to: $LOG_FILE"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Get cluster information
    local cluster_info
    cluster_info=$(get_cluster_info)
    log "DEBUG" "Cluster info: $cluster_info"
    
    # Get ArgoCD information
    local argocd_info
    argocd_info=$(get_argocd_info)
    local argocd_version
    argocd_version=$(echo "$argocd_info" | cut -d'|' -f5)
    
    if [[ -z "$argocd_version" ]]; then
        log "WARN" "Could not determine ArgoCD version - compatibility checks may be limited"
    fi
    
    # Analyze CRD compatibility
    local analysis_result
    if analyze_crd_compatibility "$argocd_version"; then
        analysis_result=$EXIT_SUCCESS
        log "INFO" "All CRDs are compatible"
    else
        analysis_result=$EXIT_COMPATIBILITY_ISSUES
        log "WARN" "Compatibility issues found"
    fi
    
    # Generate final summary and recommendations
    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        generate_final_summary "$analysis_result" "$argocd_version"
        
        if [[ -n "$(echo "$argocd_info" | cut -d'|' -f1)" ]]; then
            local helm_release chart_version
            helm_release=$(echo "$argocd_info" | cut -d'|' -f1)
            chart_version=$(echo "$argocd_info" | cut -d'|' -f2)
            echo ""
            generate_update_recommendations "$argocd_version" "$chart_version" "$helm_release"
        fi
    fi
    
    # Export results if requested
    if [[ -n "$EXPORT_FILE" ]]; then
        log "INFO" "Exporting results to: $EXPORT_FILE"
        # Implementation depends on output format
        # This is a placeholder for the export functionality
    fi
    
    log "INFO" "Analysis completed"
    cleanup
    exit $analysis_result
}

# Run main function with all arguments
main "$@"