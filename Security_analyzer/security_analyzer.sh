#!/bin/bash

# =============================================================================
# ArgoCD Security Analyzer
# Comprehensive security analysis for ArgoCD installations
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
REPORT_DIR="./security_analysis_$(date +%Y%m%d_%H%M%S)"
SEVERITY_THRESHOLD=${SEVERITY_THRESHOLD:-medium}

# Security check categories
declare -A CHECKS=(
    ["authentication"]="Authentication and SSO Configuration"
    ["authorization"]="RBAC and Authorization"
    ["network"]="Network Security"
    ["secrets"]="Secrets Management" 
    ["tls"]="TLS and Encryption"
    ["policies"]="Security Policies"
    ["compliance"]="Compliance and Best Practices"
)

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

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}        ArgoCD Security Analyzer${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Namespace: ${ARGOCD_NAMESPACE}${NC}"
    echo -e "${BLUE}Threshold: ${SEVERITY_THRESHOLD}${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    local deps=("kubectl" "jq" "yq" "openssl")
    
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
    
    mkdir -p "$REPORT_DIR"
    log_success "Prerequisites check passed"
}

# Initialize security report
init_security_report() {
    {
        echo "# ArgoCD Security Analysis Report"
        echo "Generated: $(date)"
        echo "Namespace: $ARGOCD_NAMESPACE"
        echo ""
        echo "## Executive Summary"
        echo ""
    } > "$REPORT_DIR/security_report.md"
}

# Check authentication configuration
check_authentication() {
    log_info "Analyzing authentication configuration..."
    
    {
        echo "# Authentication Security Analysis"
        echo "Generated: $(date)"
        echo ""
        echo "## Configuration Overview"
        echo ""
    } > "$REPORT_DIR/authentication.md"
    
    local issues=0
    local warnings=0
    
    # Check ArgoCD CM for auth settings
    local argocd_cm=$(kubectl get configmap argocd-cm -n "$ARGOCD_NAMESPACE" -o yaml 2>/dev/null)
    
    if [ -n "$argocd_cm" ]; then
        {
            echo "### ArgoCD Configuration"
            echo ""
            
            # Check for SSO configuration
            if echo "$argocd_cm" | grep -q "dex.config"; then
                echo "✅ **SSO Configuration**: Dex SSO is configured"
                
                # Extract and analyze Dex config
                local dex_config=$(echo "$argocd_cm" | yq eval '.data."dex.config"' - 2>/dev/null)
                if [ "$dex_config" != "null" ] && [ -n "$dex_config" ]; then
                    echo ""
                    echo "**Dex Connectors Found:**"
                    echo '```yaml'
                    echo "$dex_config" | yq eval '.connectors[] | {"type": .type, "name": .name}' - 2>/dev/null || echo "Unable to parse Dex config"
                    echo '```'
                fi
            else
                echo "⚠️ **SSO Configuration**: No Dex SSO configuration found"
                echo "- **Risk**: Users may rely on local admin account only"
                echo "- **Recommendation**: Configure SSO for better security"
                ((warnings++))
            fi
            echo ""
            
            # Check for OIDC configuration
            if echo "$argocd_cm" | grep -q "oidc.config"; then
                echo "✅ **OIDC Configuration**: OIDC is configured"
            else
                echo "ℹ️ **OIDC Configuration**: No OIDC configuration (using Dex or local auth)"
            fi
            echo ""
            
            # Check admin password policy
            echo "### Admin Account Security"
            echo ""
            
        } >> "$REPORT_DIR/authentication.md"
    else
        {
            echo "❌ **ArgoCD ConfigMap**: Not found or not accessible"
            echo "- **Risk**: Cannot analyze authentication configuration"
        } >> "$REPORT_DIR/authentication.md"
        ((issues++))
    fi
    
    # Check for admin secret
    if kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" &>/dev/null; then
        {
            echo "⚠️ **Initial Admin Secret**: Still exists"
            echo "- **Risk**: Default admin credentials may be in use"
            echo "- **Recommendation**: Remove after setting up SSO and proper admin user"
            echo ""
        } >> "$REPORT_DIR/authentication.md"
        ((warnings++))
    else
        {
            echo "✅ **Initial Admin Secret**: Properly removed"
            echo ""
        } >> "$REPORT_DIR/authentication.md"
    fi
    
    # Check server configuration for auth settings
    local server_config=$(kubectl get configmap argocd-cmd-params-cm -n "$ARGOCD_NAMESPACE" -o yaml 2>/dev/null)
    if [ -n "$server_config" ]; then
        {
            echo "### Server Authentication Settings"
            echo ""
            
            # Check for insecure settings
            if echo "$server_config" | grep -q "server.insecure.*true"; then
                echo "❌ **Insecure Mode**: Server running in insecure mode"
                echo "- **Risk**: No TLS encryption for API/UI access"
                echo "- **Recommendation**: Enable TLS immediately"
                ((issues++))
            else
                echo "✅ **Secure Mode**: Server running with TLS enabled"
            fi
            echo ""
            
            # Check for disable auth
            if echo "$server_config" | grep -q "server.disable.auth.*true"; then
                echo "❌ **Authentication Disabled**: Server authentication is disabled"
                echo "- **Risk**: No authentication required for access"
                echo "- **Recommendation**: Enable authentication immediately"
                ((issues++))
            else
                echo "✅ **Authentication Enabled**: Server authentication is properly enabled"
            fi
            echo ""
            
        } >> "$REPORT_DIR/authentication.md"
    fi
    
    # Summary
    {
        echo "## Authentication Security Summary"
        echo ""
        echo "- **Critical Issues**: $issues"
        echo "- **Warnings**: $warnings"
        echo ""
        
        if [ $issues -eq 0 ] && [ $warnings -eq 0 ]; then
            echo "🟢 **Overall Status**: Good - No critical authentication issues found"
        elif [ $issues -eq 0 ]; then
            echo "🟡 **Overall Status**: Acceptable - Minor warnings to address"
        else
            echo "🔴 **Overall Status**: Critical - Immediate attention required"
        fi
        
    } >> "$REPORT_DIR/authentication.md"
    
    log_success "Authentication analysis complete: $issues issues, $warnings warnings"
    echo "$issues,$warnings" > "$REPORT_DIR/.auth_stats"
}

# Check RBAC and authorization
check_authorization() {
    log_info "Analyzing RBAC and authorization..."
    
    {
        echo "# Authorization Security Analysis"
        echo "Generated: $(date)"
        echo ""
        echo "## RBAC Configuration"
        echo ""
    } > "$REPORT_DIR/authorization.md"
    
    local issues=0
    local warnings=0
    
    # Check ArgoCD RBAC configuration
    local rbac_cm=$(kubectl get configmap argocd-rbac-cm -n "$ARGOCD_NAMESPACE" -o yaml 2>/dev/null)
    
    if [ -n "$rbac_cm" ]; then
        {
            echo "### ArgoCD RBAC ConfigMap"
            echo ""
            
            # Check for policy.default
            local default_policy=$(echo "$rbac_cm" | yq eval '.data."policy.default"' - 2>/dev/null)
            if [ "$default_policy" = "role:admin" ]; then
                echo "❌ **Default Policy**: Set to admin role"
                echo "- **Risk**: All authenticated users get admin privileges"
                echo "- **Recommendation**: Set to read-only or create specific roles"
                ((issues++))
            elif [ "$default_policy" = "role:readonly" ]; then
                echo "✅ **Default Policy**: Set to read-only (secure)"
            elif [ "$default_policy" = "" ] || [ "$default_policy" = "null" ]; then
                echo "⚠️ **Default Policy**: Not explicitly set"
                echo "- **Risk**: Behavior may be unpredictable"
                echo "- **Recommendation**: Explicitly set default policy"
                ((warnings++))
            else
                echo "ℹ️ **Default Policy**: Set to custom role: $default_policy"
            fi
            echo ""
            
            # Check for policy.csv
            local policy_csv=$(echo "$rbac_cm" | yq eval '.data."policy.csv"' - 2>/dev/null)
            if [ "$policy_csv" != "null" ] && [ -n "$policy_csv" ]; then
                echo "✅ **Custom Policies**: RBAC policies are defined"
                echo ""
                echo "**Policy Rules Count:**"
                local rule_count=$(echo "$policy_csv" | grep -c "^p," 2>/dev/null || echo "0")
                local role_count=$(echo "$policy_csv" | grep -c "^g," 2>/dev/null || echo "0")
                echo "- Policy rules: $rule_count"
                echo "- Role bindings: $role_count"
                echo ""
                
                # Check for overly permissive rules
                if echo "$policy_csv" | grep -q "\*.*\*.*allow"; then
                    echo "⚠️ **Permissive Rules**: Found rules with wildcard permissions"
                    echo "- **Risk**: May grant excessive permissions"
                    echo "- **Recommendation**: Review and restrict permissions"
                    ((warnings++))
                fi
            else
                echo "⚠️ **Custom Policies**: No custom RBAC policies defined"
                echo "- **Risk**: Relying only on default policy"
                echo "- **Recommendation**: Define granular RBAC policies"
                ((warnings++))
            fi
            echo ""
            
        } >> "$REPORT_DIR/authorization.md"
    else
        {
            echo "⚠️ **ArgoCD RBAC ConfigMap**: Not found or not configured"
            echo "- **Risk**: Default RBAC behavior may be permissive"
            echo "- **Recommendation**: Configure explicit RBAC policies"
            echo ""
        } >> "$REPORT_DIR/authorization.md"
        ((warnings++))
    fi
    
    # Check Kubernetes RBAC for ArgoCD
    {
        echo "### Kubernetes RBAC Analysis"
        echo ""
        
        # Check ClusterRoles
        local cluster_roles=$(kubectl get clusterroles | grep argocd | wc -l)
        echo "**ArgoCD ClusterRoles**: $cluster_roles found"
        
        # Check for overly broad permissions
        local admin_cluster_roles=$(kubectl get clusterroles -o json | jq -r '.items[] | select(.metadata.name | contains("argocd")) | select(.rules[] | select(.verbs[] == "*" and .resources[] == "*")) | .metadata.name' 2>/dev/null)
        
        if [ -n "$admin_cluster_roles" ]; then
            echo ""
            echo "⚠️ **Broad Permissions**: Found ClusterRoles with admin-level permissions:"
            echo "$admin_cluster_roles" | while read -r role; do
                echo "- $role"
            done
            echo "- **Risk**: Excessive cluster-wide permissions"
            echo "- **Recommendation**: Review and restrict to minimum required"
            ((warnings++))
        else
            echo "✅ **Restricted Permissions**: No overly broad ClusterRoles found"
        fi
        echo ""
        
        # Check ServiceAccounts
        local service_accounts=$(kubectl get serviceaccounts -n "$ARGOCD_NAMESPACE" | grep argocd | wc -l)
        echo "**ArgoCD ServiceAccounts**: $service_accounts found"
        
    } >> "$REPORT_DIR/authorization.md"
    
    # Check for Project-level RBAC
    {
        echo "### Application Project Security"
        echo ""
        
        local projects=$(kubectl get appprojects -A --no-headers 2>/dev/null | wc -l)
        echo "**AppProjects Found**: $projects"
        
        if [ $projects -gt 0 ]; then
            # Check for default project restrictions
            local default_project=$(kubectl get appproject default -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null)
            if [ -n "$default_project" ]; then
                local source_repos=$(echo "$default_project" | jq -r '.spec.sourceRepos[]?' 2>/dev/null | wc -l)
                local destinations=$(echo "$default_project" | jq -r '.spec.destinations[]?' 2>/dev/null | wc -l)
                
                echo ""
                echo "**Default Project Configuration:**"
                echo "- Source repositories: $source_repos"
                echo "- Destinations: $destinations"
                
                # Check for wildcard permissions
                if echo "$default_project" | jq -r '.spec.sourceRepos[]?' 2>/dev/null | grep -q '\*'; then
                    echo "⚠️ **Wildcard Source Repos**: Default project allows any repository"
                    echo "- **Risk**: Applications can be deployed from any Git repository"
                    echo "- **Recommendation**: Restrict to specific trusted repositories"
                    ((warnings++))
                fi
                
                if echo "$default_project" | jq -r '.spec.destinations[].server' 2>/dev/null | grep -q '\*'; then
                    echo "⚠️ **Wildcard Destinations**: Default project allows any cluster"
                    echo "- **Risk**: Applications can be deployed to any cluster"
                    echo "- **Recommendation**: Restrict to specific clusters"
                    ((warnings++))
                fi
            fi
        else
            echo "ℹ️ **No AppProjects**: Using default project configuration"
        fi
        echo ""
        
    } >> "$REPORT_DIR/authorization.md"
    
    # Summary
    {
        echo "## Authorization Security Summary"
        echo ""
        echo "- **Critical Issues**: $issues"
        echo "- **Warnings**: $warnings"
        echo ""
        
        if [ $issues -eq 0 ] && [ $warnings -eq 0 ]; then
            echo "🟢 **Overall Status**: Good - Proper RBAC configuration"
        elif [ $issues -eq 0 ]; then
            echo "🟡 **Overall Status**: Acceptable - Consider addressing warnings"
        else
            echo "🔴 **Overall Status**: Critical - Fix authorization issues immediately"
        fi
        
    } >> "$REPORT_DIR/authorization.md"
    
    log_success "Authorization analysis complete: $issues issues, $warnings warnings"
    echo "$issues,$warnings" > "$REPORT_DIR/.auth_rbac_stats"
}

# Check network security
check_network_security() {
    log_info "Analyzing network security..."
    
    {
        echo "# Network Security Analysis"
        echo "Generated: $(date)"
        echo ""
        echo "## Service Configuration"
        echo ""
    } > "$REPORT_DIR/network.md"
    
    local issues=0
    local warnings=0
    
    # Check ArgoCD services
    local services=$(kubectl get services -n "$ARGOCD_NAMESPACE" -o json)
    
    {
        echo "### ArgoCD Services"
        echo ""
        echo "| Service | Type | Ports | External Access |"
        echo "|---------|------|-------|----------------|"
        
        echo "$services" | jq -r '.items[] | select(.metadata.name | contains("argocd")) | "\(.metadata.name),\(.spec.type),\(.spec.ports | map("\(.port):\(.targetPort)") | join(" ")),\(if .spec.type == "LoadBalancer" or .spec.type == "NodePort" then "YES" else "NO" end)"' | \
        while IFS=',' read -r name type ports external; do
            echo "| $name | $type | $ports | $external |"
            
            # Check for insecure external exposure
            if [ "$external" = "YES" ] && [[ "$name" == *"server"* ]]; then
                if [ "$type" = "LoadBalancer" ]; then
                    echo ""
                    echo "⚠️ **LoadBalancer Exposure**: $name exposed via LoadBalancer"
                    echo "- **Risk**: Direct internet access to ArgoCD"
                    echo "- **Recommendation**: Use Ingress with proper TLS and authentication"
                    ((warnings++))
                elif [ "$type" = "NodePort" ]; then
                    echo ""
                    echo "⚠️ **NodePort Exposure**: $name exposed via NodePort"
                    echo "- **Risk**: Direct access via node IPs"
                    echo "- **Recommendation**: Use Ingress or LoadBalancer with proper controls"
                    ((warnings++))
                fi
            fi
        done
        echo ""
        
    } >> "$REPORT_DIR/network.md"
    
    # Check for NetworkPolicies
    {
        echo "### Network Policies"
        echo ""
        
        local network_policies=$(kubectl get networkpolicies -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [ $network_policies -gt 0 ]; then
            echo "✅ **Network Policies**: $network_policies policies found"
            echo ""
            echo "**Configured Policies:**"
            kubectl get networkpolicies -n "$ARGOCD_NAMESPACE" -o custom-columns=NAME:.metadata.name,INGRESS:.spec.ingress,EGRESS:.spec.egress --no-headers 2>/dev/null | \
            while read -r name ingress egress; do
                echo "- $name (Ingress: ${ingress:-none}, Egress: ${egress:-none})"
            done
        else
            echo "⚠️ **Network Policies**: No NetworkPolicies found"
            echo "- **Risk**: No network segmentation for ArgoCD pods"
            echo "- **Recommendation**: Implement NetworkPolicies to restrict traffic"
            ((warnings++))
        fi
        echo ""
        
    } >> "$REPORT_DIR/network.md"
    
    # Check Ingress configuration
    {
        echo "### Ingress Configuration"
        echo ""
        
        local ingresses=$(kubectl get ingresses -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [ $ingresses -gt 0 ]; then
            echo "✅ **Ingress Resources**: $ingresses ingress(es) found"
            echo ""
            
            # Check TLS configuration
            kubectl get ingresses -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null | \
            jq -r '.items[] | "\(.metadata.name),\(.spec.tls // [] | length),\(.spec.rules[].host)"' | \
            while IFS=',' read -r name tls_count host; do
                echo "**$name**:"
                echo "- Host: $host"
                
                if [ "$tls_count" -gt 0 ]; then
                    echo "- TLS: ✅ Configured"
                else
                    echo "- TLS: ❌ Not configured"
                    echo "  - **Risk**: Unencrypted traffic"
                    echo "  - **Recommendation**: Configure TLS certificate"
                    ((issues++))
                fi
                echo ""
            done
        else
            echo "ℹ️ **Ingress Resources**: No ingresses found (may use LoadBalancer or NodePort)"
        fi
        echo ""
        
    } >> "$REPORT_DIR/network.md"
    
    # Summary
    {
        echo "## Network Security Summary"
        echo ""
        echo "- **Critical Issues**: $issues"
        echo "- **Warnings**: $warnings"
        echo ""
        
        if [ $issues -eq 0 ] && [ $warnings -eq 0 ]; then
            echo "🟢 **Overall Status**: Good - Proper network security configuration"
        elif [ $issues -eq 0 ]; then
            echo "🟡 **Overall Status**: Acceptable - Consider implementing recommendations"
        else
            echo "🔴 **Overall Status**: Critical - Fix network security issues immediately"
        fi
        
    } >> "$REPORT_DIR/network.md"
    
    log_success "Network security analysis complete: $issues issues, $warnings warnings"
    echo "$issues,$warnings" > "$REPORT_DIR/.network_stats"
}

# Check secrets management
check_secrets_management() {
    log_info "Analyzing secrets management..."
    
    {
        echo "# Secrets Management Analysis"
        echo "Generated: $(date)"
        echo ""
        echo "## ArgoCD Secrets Overview"
        echo ""
    } > "$REPORT_DIR/secrets.md"
    
    local issues=0
    local warnings=0
    
    # Get all secrets in ArgoCD namespace
    local secrets=$(kubectl get secrets -n "$ARGOCD_NAMESPACE" -o json)
    
    {
        echo "### Secret Inventory"
        echo ""
        echo "| Secret Name | Type | Keys | Age |"
        echo "|-------------|------|------|-----|"
        
        echo "$secrets" | jq -r '.items[] | "\(.metadata.name),\(.type),\(.data | keys | length),\(.metadata.creationTimestamp)"' | \
        while IFS=',' read -r name type key_count age; do
            local age_days=$(( ($(date +%s) - $(date -d "$age" +%s)) / 86400 ))
            echo "| $name | $type | $key_count | ${age_days}d |"
        done
        echo ""
        
    } >> "$REPORT_DIR/secrets.md"
    
    # Check for sensitive secrets
    {
        echo "### Sensitive Secrets Analysis"
        echo ""
        
        # Check admin password
        if kubectl get secret argocd-secret -n "$ARGOCD_NAMESPACE" &>/dev/null; then
            local admin_password_set=$(kubectl get secret argocd-secret -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d 2>/dev/null | wc -c)
            
            if [ "$admin_password_set" -gt 0 ]; then
                echo "✅ **Admin Password**: Set in argocd-secret"
                
                # Check password strength (basic check)
                local password=$(kubectl get secret argocd-secret -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d 2>/dev/null)
                local pwd_length=${#password}
                
                if [ "$pwd_length" -lt 12 ]; then
                    echo "⚠️ **Password Strength**: Admin password is short (< 12 characters)"
                    echo "- **Risk**: Weak password may be easily compromised"
                    echo "- **Recommendation**: Use strong password (>12 chars, mixed case, numbers, symbols)"
                    ((warnings++))
                else
                    echo "✅ **Password Strength**: Admin password meets minimum length"
                fi
            else
                echo "⚠️ **Admin Password**: Not set in argocd-secret"
                echo "- **Risk**: May be using default or initial admin password"
                ((warnings++))
            fi
            echo ""
        fi
        
        # Check for repository secrets
        local repo_secrets=$(echo "$secrets" | jq -r '.items[] | select(.metadata.labels."argocd.argoproj.io/secret-type" == "repo-creds" or .metadata.labels."argocd.argoproj.io/secret-type" == "repository") | .metadata.name')
        
        if [ -n "$repo_secrets" ]; then
            echo "**Repository Secrets Found:**"
            echo "$repo_secrets" | while read -r secret_name; do
                echo "- $secret_name"
                
                # Check if secret contains SSH keys
                if kubectl get secret "$secret_name" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data}' 2>/dev/null | grep -q "sshPrivateKey"; then
                    echo "  - Type: SSH Key"
                    
                    # Check SSH key strength (basic)
                    local ssh_key=$(kubectl get secret "$secret_name" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.sshPrivateKey}' 2>/dev/null | base64 -d 2>/dev/null)
                    if echo "$ssh_key" | grep -q "BEGIN RSA PRIVATE KEY"; then
                        local key_size=$(echo "$ssh_key" | openssl rsa -text -noout 2>/dev/null | grep "Private-Key" | awk '{print $2}' | tr -d '()')
                        if [ "$key_size" -lt 2048 ] 2>/dev/null; then
                            echo "  - ⚠️ RSA key size < 2048 bits"
                            ((warnings++))
                        else
                            echo "  - ✅ RSA key size adequate"
                        fi
                    elif echo "$ssh_key" | grep -q "BEGIN OPENSSH PRIVATE KEY"; then
                        echo "  - ✅ Modern OpenSSH key format"
                    fi
                    
                elif kubectl get secret "$secret_name" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data}' 2>/dev/null | grep -q "password"; then
                    echo "  - Type: Username/Password"
                fi
            done
            echo ""
        else
            echo "ℹ️ **Repository Secrets**: No repository credential secrets found"
            echo ""
        fi
        
        # Check for cluster secrets
        local cluster_secrets=$(echo "$secrets" | jq -r '.items[] | select(.metadata.labels."argocd.argoproj.io/secret-type" == "cluster") | .metadata.name')
        
        if [ -n "$cluster_secrets" ]; then
            echo "**Cluster Secrets Found:**"
            echo "$cluster_secrets" | while read -r secret_name; do
                echo "- $secret_name"
                
                # Check if using service account token vs certificate
                if kubectl get secret "$secret_name" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data}' 2>/dev/null | grep -q "bearerToken"; then
                    echo "  - Auth: Bearer Token"
                    echo "  - ⚠️ Consider using certificate-based auth for better security"
                    ((warnings++))
                elif kubectl get secret "$secret_name" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data}' 2>/dev/null | grep -q "clientCert"; then
                    echo "  - Auth: Certificate (more secure)"
                fi
            done
            echo ""
        fi
        
    } >> "$REPORT_DIR/secrets.md"
    
    # Check secret encryption
    {
        echo "### Secret Encryption"
        echo ""
        
        # Check if etcd encryption is enabled (cluster-level check)
        local etcd_encryption_check=$(kubectl get --raw /api/v1/namespaces/kube-system/secrets 2>/dev/null | jq -r '.items[0].metadata.name' 2>/dev/null)
        
        if [ -n "$etcd_encryption_check" ]; then
            echo "✅ **Etcd Access**: Can access secrets (encryption status unknown)"
            echo "- **Note**: Verify etcd encryption at rest with cluster administrator"
        else
            echo "⚠️ **Etcd Access**: Cannot verify secret encryption status"
        fi
        echo ""
        
        # Check for external secret management
        if kubectl get crd externalsecrets.external-secrets.io &>/dev/null; then
            echo "✅ **External Secrets**: External Secrets Operator detected"
            local external_secrets=$(kubectl get externalsecrets -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l)
            echo "- External secrets in namespace: $external_secrets"
        elif kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io &>/dev/null; then
            echo "✅ **Secret Store CSI**: Secret Store CSI Driver detected"
        else
            echo "ℹ️ **External Secrets**: No external secret management detected"
            echo "- **Recommendation**: Consider using external secret management for production"
        fi
        echo ""
        
    } >> "$REPORT_DIR/secrets.md"
    
    # Summary
    {
        echo "## Secrets Management Summary"
        echo ""
        echo "- **Critical Issues**: $issues"
        echo "- **Warnings**: $warnings"
        echo ""
        
        if [ $issues -eq 0 ] && [ $warnings -eq 0 ]; then
            echo "🟢 **Overall Status**: Good - Secrets are properly managed"
        elif [ $issues -eq 0 ]; then
            echo "🟡 **Overall Status**: Acceptable - Consider addressing warnings"
        else
            echo "🔴 **Overall Status**: Critical - Fix secret management issues immediately"
        fi
        
    } >> "$REPORT_DIR/secrets.md"
    
    log_success "Secrets management analysis complete: $issues issues, $warnings warnings"
    echo "$issues,$warnings" > "$REPORT_DIR/.secrets_stats"
}

# Generate comprehensive security report
generate_comprehensive_report() {
    log_info "Generating comprehensive security report..."
    
    # Collect all statistics
    local auth_stats=$(cat "$REPORT_DIR/.auth_stats" 2>/dev/null || echo "0,0")
    local rbac_stats=$(cat "$REPORT_DIR/.auth_rbac_stats" 2>/dev/null || echo "0,0")
    local network_stats=$(cat "$REPORT_DIR/.network_stats" 2>/dev/null || echo "0,0")
    local secrets_stats=$(cat "$REPORT_DIR/.secrets_stats" 2>/dev/null || echo "0,0")
    
    local total_issues=0
    local total_warnings=0
    
    IFS=',' read -r auth_issues auth_warnings <<< "$auth_stats"
    IFS=',' read -r rbac_issues rbac_warnings <<< "$rbac_stats"
    IFS=',' read -r network_issues network_warnings <<< "$network_stats"
    IFS=',' read -r secrets_issues secrets_warnings <<< "$secrets_stats"
    
    total_issues=$((auth_issues + rbac_issues + network_issues + secrets_issues))
    total_warnings=$((auth_warnings + rbac_warnings + network_warnings + secrets_warnings))
    
    {
        echo "# ArgoCD Security Analysis - Executive Summary"
        echo "Generated: $(date)"
        echo ""
        echo "## Overall Security Score"
        echo ""
        
        local security_score=100
        security_score=$((security_score - total_issues * 20 - total_warnings * 5))
        if [ $security_score -lt 0 ]; then
            security_score=0
        fi
        
        echo "### Security Score: $security_score/100"
        echo ""
        
        if [ $security_score -ge 80 ]; then
            echo "🟢 **Overall Status**: Good Security Posture"
        elif [ $security_score -ge 60 ]; then
            echo "🟡 **Overall Status**: Acceptable - Improvements Needed"
        else
            echo "🔴 **Overall Status**: Poor - Immediate Action Required"
        fi
        echo ""
        
        echo "## Summary Statistics"
        echo ""
        echo "| Category | Issues | Warnings | Status |"
        echo "|----------|--------|----------|--------|"
        
        local auth_status="🟢 Good"
        if [ $auth_issues -gt 0 ]; then auth_status="🔴 Critical"; elif [ $auth_warnings -gt 0 ]; then auth_status="🟡 Warning"; fi
        echo "| Authentication | $auth_issues | $auth_warnings | $auth_status |"
        
        local rbac_status="🟢 Good"
        if [ $rbac_issues -gt 0 ]; then rbac_status="🔴 Critical"; elif [ $rbac_warnings -gt 0 ]; then rbac_status="🟡 Warning"; fi
        echo "| Authorization | $rbac_issues | $rbac_warnings | $rbac_status |"
        
        local network_status="🟢 Good"
        if [ $network_issues -gt 0 ]; then network_status="🔴 Critical"; elif [ $network_warnings -gt 0 ]; then network_status="🟡 Warning"; fi
        echo "| Network Security | $network_issues | $network_warnings | $network_status |"
        
        local secrets_status="🟢 Good"
        if [ $secrets_issues -gt 0 ]; then secrets_status="🔴 Critical"; elif [ $secrets_warnings -gt 0 ]; then secrets_status="🟡 Warning"; fi
        echo "| Secrets Management | $secrets_issues | $secrets_warnings | $secrets_status |"
        
        echo "| **Total** | **$total_issues** | **$total_warnings** | |"
        echo ""
        
        echo "## Priority Actions"
        echo ""
        
        if [ $total_issues -gt 0 ]; then
            echo "### 🚨 Critical Issues (Fix Immediately)"
            if [ $auth_issues -gt 0 ]; then
                echo "- **Authentication**: Review authentication.md for critical security gaps"
            fi
            if [ $rbac_issues -gt 0 ]; then
                echo "- **Authorization**: Review authorization.md for RBAC misconfigurations"
            fi
            if [ $network_issues -gt 0 ]; then
                echo "- **Network**: Review network.md for network security issues"
            fi
            if [ $secrets_issues -gt 0 ]; then
                echo "- **Secrets**: Review secrets.md for secret management problems"
            fi
            echo ""
        fi
        
        if [ $total_warnings -gt 0 ]; then
            echo "### ⚠️ Warnings (Address Soon)"
            if [ $auth_warnings -gt 0 ]; then
                echo "- **Authentication**: $auth_warnings warning(s) in authentication configuration"
            fi
            if [ $rbac_warnings -gt 0 ]; then
                echo "- **Authorization**: $rbac_warnings warning(s) in RBAC configuration"
            fi
            if [ $network_warnings -gt 0 ]; then
                echo "- **Network Security**: $network_warnings warning(s) in network configuration"
            fi
            if [ $secrets_warnings -gt 0 ]; then
                echo "- **Secrets Management**: $secrets_warnings warning(s) in secrets handling"
            fi
            echo ""
        fi
        
        echo "## Detailed Reports"
        echo ""
        echo "1. **authentication.md** - SSO, authentication methods, admin accounts"
        echo "2. **authorization.md** - RBAC policies, permissions, project security"
        echo "3. **network.md** - Service exposure, network policies, TLS"
        echo "4. **secrets.md** - Secret management, encryption, credential security"
        echo ""
        
        echo "## Security Recommendations"
        echo ""
        echo "### Immediate Actions"
        echo "- Fix all critical issues identified above"
        echo "- Review and implement strong authentication (SSO preferred)"
        echo "- Configure restrictive RBAC policies"
        echo "- Enable TLS for all communications"
        echo "- Use strong passwords and rotate regularly"
        echo ""
        
        echo "### Long-term Improvements"
        echo "- Implement network segmentation with NetworkPolicies"
        echo "- Use external secret management systems"
        echo "- Regular security audits and reviews"
        echo "- Monitor and log security events"
        echo "- Keep ArgoCD updated to latest secure version"
        
    } > "$REPORT_DIR/executive_summary.md"
    
    # Copy to main security report
    cp "$REPORT_DIR/executive_summary.md" "$REPORT_DIR/security_report.md"
    
    # Clean up temporary files
    rm -f "$REPORT_DIR/.auth_stats" "$REPORT_DIR/.auth_rbac_stats" "$REPORT_DIR/.network_stats" "$REPORT_DIR/.secrets_stats"
}

# Main execution
main() {
    print_header
    
    check_prerequisites
    init_security_report
    
    # Run all security checks
    check_authentication
    check_authorization  
    check_network_security
    check_secrets_management
    
    generate_comprehensive_report
    
    echo
    log_success "Security analysis completed successfully!"
    log_info "Report available in: $REPORT_DIR/"
    echo
    echo -e "${CYAN}To view the executive summary:${NC}"
    echo "  cat $REPORT_DIR/executive_summary.md"
    echo ""
    echo -e "${CYAN}To view detailed analysis:${NC}"
    echo "  ls $REPORT_DIR/*.md"
    echo ""
    
    # Show quick summary
    local total_files=$(ls "$REPORT_DIR"/*.md 2>/dev/null | wc -l)
    echo -e "${BLUE}Generated $total_files detailed security reports${NC}"
}

# Show usage
show_usage() {
    echo "ArgoCD Security Analyzer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAME      ArgoCD namespace (default: argocd)"
    echo "  -t, --threshold LEVEL     Severity threshold (low|medium|high, default: medium)"
    echo "  -h, --help               Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  ARGOCD_NAMESPACE         ArgoCD namespace"
    echo "  SEVERITY_THRESHOLD       Minimum severity to report"
    echo ""
    echo "Examples:"
    echo "  $0                              # Default analysis"
    echo "  $0 --namespace argocd-prod      # Custom namespace"
    echo "  $0 --threshold high             # Only high severity issues"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            ARGOCD_NAMESPACE="$2"
            shift 2
            ;;
        -t|--threshold)
            SEVERITY_THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi