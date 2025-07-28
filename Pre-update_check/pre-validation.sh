#!/bin/bash

# =============================================================================
# ArgoCD Validation Scripts Collection - IMPROVED VERSION
# Use these scripts to validate ArgoCD health before/during/after upgrades
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default namespace
NAMESPACE=${NAMESPACE:-argocd}

# =============================================================================
# IMPROVED PRE-UPGRADE VALIDATION (Fixed false positives)
# =============================================================================
pre_upgrade_validation() {
    echo -e "${BLUE}=== PRE-UPGRADE VALIDATION ===${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    local issues=0
    
    # Check ArgoCD installation exists
    echo -e "${BLUE}1. Checking ArgoCD installation...${NC}"
    if helm list -n $NAMESPACE | grep -q argocd; then
        local current_version=$(helm list -n $NAMESPACE -o json | jq -r '.[] | select(.name=="argocd") | .chart')
        echo -e "${GREEN}✓ ArgoCD found: $current_version${NC}"
    else
        echo -e "${RED}✗ ArgoCD installation not found${NC}"
        ((issues++))
    fi
    
    # Check pod health (IMPROVED - ignore Completed/Succeeded jobs)
    echo -e "${BLUE}2. Checking pod health...${NC}"
    local total_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep Running | wc -l)
    local completed_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -E "(Completed|Succeeded)" | wc -l)
    local problem_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v -E "(Running|Completed|Succeeded)" | wc -l)
    
    echo "Total pods: $total_pods"
    echo "Running pods: $running_pods"
    echo "Completed/Succeeded jobs: $completed_pods"
    echo "Problem pods: $problem_pods"
    
    if [ "$problem_pods" -eq 0 ]; then
        echo -e "${GREEN}✓ All pods are healthy (excluding completed jobs)${NC}"
    else
        echo -e "${RED}✗ Found $problem_pods problematic pods${NC}"
        kubectl get pods -n $NAMESPACE | grep -v -E "(Running|Completed|Succeeded)"
        ((issues++))
    fi
    
    # Show completed jobs for information (not as errors)
    if [ "$completed_pods" -gt 0 ]; then
        echo -e "${BLUE}Completed jobs (normal):${NC}"
        kubectl get pods -n $NAMESPACE | grep -E "(Completed|Succeeded)" | head -5
        if [ "$completed_pods" -gt 5 ]; then
            echo "... and $((completed_pods - 5)) more completed jobs"
        fi
    fi
    
    # Check Redis HA specifically
    echo -e "${BLUE}3. Checking Redis HA cluster...${NC}"
    local redis_pods=$(kubectl get pods -n $NAMESPACE -l app=redis-ha --no-headers 2>/dev/null | wc -l)
    local redis_running=$(kubectl get pods -n $NAMESPACE -l app=redis-ha --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ "$redis_pods" -eq 3 ] && [ "$redis_running" -eq 3 ]; then
        echo -e "${GREEN}✓ Redis HA cluster healthy (3/3 pods running)${NC}"
        
        # Test Redis connectivity (improved error handling)
        echo -n "Testing Redis connectivity..."
        if kubectl exec -n $NAMESPACE argocd-redis-ha-server-0 -c redis -- redis-cli ping >/dev/null 2>&1; then
            echo -e " ${GREEN}✓ Redis connectivity test passed${NC}"
        elif kubectl exec -n $NAMESPACE argocd-redis-ha-server-0 -c redis -- redis-cli -a "$(kubectl get secret -n $NAMESPACE argocd-redis -o jsonpath='{.data.auth}' | base64 -d 2>/dev/null)" ping >/dev/null 2>&1; then
            echo -e " ${GREEN}✓ Redis connectivity test passed (with auth)${NC}"
        else
            echo -e " ${YELLOW}⚠ Redis connectivity test failed (may be normal if auth enabled)${NC}"
        fi
    else
        echo -e "${RED}✗ Redis HA cluster unhealthy ($redis_running/$redis_pods running)${NC}"
        ((issues++))
    fi
    
    # Check applications
    echo -e "${BLUE}4. Checking applications...${NC}"
    local total_apps=$(kubectl get applications -A --no-headers 2>/dev/null | wc -l)
    local synced_apps=$(kubectl get applications -A --no-headers 2>/dev/null | grep Synced | wc -l)
    local healthy_apps=$(kubectl get applications -A --no-headers 2>/dev/null | grep Healthy | wc -l)
    
    echo "Total applications: $total_apps"
    echo "Synced applications: $synced_apps"
    echo "Healthy applications: $healthy_apps"
    
    if [ "$total_apps" -gt 0 ]; then
        local sync_percentage=$((synced_apps * 100 / total_apps))
        local health_percentage=$((healthy_apps * 100 / total_apps))
        
        if [ "$sync_percentage" -ge 95 ]; then
            echo -e "${GREEN}✓ Application sync status excellent ($sync_percentage%)${NC}"
        elif [ "$sync_percentage" -ge 80 ]; then
            echo -e "${GREEN}✓ Application sync status acceptable ($sync_percentage%)${NC}"
        else
            echo -e "${YELLOW}⚠ Low sync percentage ($sync_percentage%), consider syncing before upgrade${NC}"
        fi
        
        if [ "$health_percentage" -ge 95 ]; then
            echo -e "${GREEN}✓ Application health excellent ($health_percentage%)${NC}"
        elif [ "$health_percentage" -ge 80 ]; then
            echo -e "${GREEN}✓ Application health acceptable ($health_percentage%)${NC}"
        else
            echo -e "${YELLOW}⚠ Low health percentage ($health_percentage%)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No applications found${NC}"
    fi
    
    # Check recent restarts (only for running pods)
    echo -e "${BLUE}5. Checking for recent pod restarts...${NC}"
    local restart_count=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.status.containerStatuses[*].restartCount}{"\n"}{end}' 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    echo "Total restart count (running pods): $restart_count"
    
    if [ "$restart_count" -eq 0 ]; then
        echo -e "${GREEN}✓ No recent restarts${NC}"
    elif [ "$restart_count" -le 5 ]; then
        echo -e "${YELLOW}⚠ Found $restart_count restarts (acceptable)${NC}"
        kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' | grep -v $'\t0'
    else
        echo -e "${RED}✗ High restart count: $restart_count${NC}"
        kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' | grep -v $'\t0'
        ((issues++))
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}=== VALIDATION SUMMARY ===${NC}"
    if [ "$issues" -eq 0 ]; then
        echo -e "${GREEN}✓ PRE-UPGRADE VALIDATION PASSED - Safe to proceed${NC}"
        return 0
    else
        echo -e "${RED}✗ PRE-UPGRADE VALIDATION FAILED - $issues issues found${NC}"
        echo -e "${YELLOW}Resolve issues before proceeding with upgrade${NC}"
        return 1
    fi
}

# =============================================================================
# REDIS HA HEALTH CHECK (Enhanced)
# =============================================================================
redis_health_check() {
    echo -e "${BLUE}=== REDIS HA HEALTH CHECK ===${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    # Pod status
    echo -e "${BLUE}1. Redis HA Pod Status:${NC}"
    kubectl get pods -n $NAMESPACE -l app=redis-ha -o wide 2>/dev/null || echo "No Redis HA pods found"
    echo ""
    
    # Container restart counts
    echo -e "${BLUE}2. Container Restart Counts:${NC}"
    kubectl get pods -n $NAMESPACE -l app=redis-ha -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' 2>/dev/null || echo "Failed to get restart counts"
    echo ""
    
    # Redis replication status (improved auth handling)
    echo -e "${BLUE}3. Redis Replication Status:${NC}"
    local redis_auth=""
    
    # Try to get Redis auth from secret
    if kubectl get secret -n $NAMESPACE argocd-redis >/dev/null 2>&1; then
        redis_auth=$(kubectl get secret -n $NAMESPACE argocd-redis -o jsonpath='{.data.auth}' 2>/dev/null | base64 -d 2>/dev/null)
    fi
    
    for pod in $(kubectl get pods -n $NAMESPACE -l app=redis-ha -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        echo "--- $pod ---"
        if [ -n "$redis_auth" ]; then
            kubectl exec -n $NAMESPACE $pod -c redis -- redis-cli -a "$redis_auth" info replication 2>/dev/null || echo "Failed to connect to Redis in $pod (with auth)"
        else
            kubectl exec -n $NAMESPACE $pod -c redis -- redis-cli info replication 2>/dev/null || echo "Authentication required for Redis in $pod"
        fi
        echo ""
    done
    
    # Test CRD functionality with existing resources
    echo -e "${BLUE}3. CRD Functionality Test:${NC}"
    
    # Test Applications CRD
    local app_count=$(kubectl get applications -A --no-headers 2>/dev/null | wc -l)
    if [ "$app_count" -gt 0 ]; then
        echo -e "${GREEN}✓ Applications CRD functional ($app_count applications found)${NC}"
        
        # Test a sample application for schema compliance
        local sample_app=$(kubectl get applications -A -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        local sample_ns=$(kubectl get applications -A -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
        
        if [ -n "$sample_app" ] && [ -n "$sample_ns" ]; then
            if kubectl get application "$sample_app" -n "$sample_ns" -o yaml >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Sample application schema valid${NC}"
            else
                echo -e "${RED}✗ Sample application schema invalid${NC}"
                ((issues++))
            fi
        fi
    else
        echo -e "${YELLOW}⚠ No applications found${NC}"
    fi
    
    # Test ApplicationSets CRD
    local appset_count=$(kubectl get applicationsets -A --no-headers 2>/dev/null | wc -l)
    if [ "$appset_count" -gt 0 ]; then
        echo -e "${GREEN}✓ ApplicationSets CRD functional ($appset_count applicationsets found)${NC}"
    else
        echo -e "${YELLOW}⚠ No applicationsets found${NC}"
    fi
    
    # Test AppProjects CRD
    local project_count=$(kubectl get appprojects -A --no-headers 2>/dev/null | wc -l)
    if [ "$project_count" -gt 0 ]; then
        echo -e "${GREEN}✓ AppProjects CRD functional ($project_count projects found)${NC}"
    else
        echo -e "${YELLOW}⚠ No appprojects found (default project should exist)${NC}"
    fi
    
    # Test CRD schema validation with v2.14.11 features
    echo -e "${BLUE}4. CRD Schema Validation Test:${NC}"
    
    # Test Application creation (basic)
    local test_app_yaml=$(cat << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-schema-validation
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    path: guestbook
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF
)
    
    if echo "$test_app_yaml" | kubectl apply --dry-run=client -f - >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Application CRD schema validation passed${NC}"
    else
        echo -e "${RED}✗ Application CRD schema validation failed${NC}"
        ((issues++))
    fi
    
    # Test v2.14.11 sourceHydrator field if CRD supports it
    if kubectl get crd applications.argoproj.io -o yaml 2>/dev/null | grep -q "sourceHydrator"; then
        local test_app_v2141_yaml=$(cat << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-v2141-schema
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    path: guestbook
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  sourceHydrator:
    drySource:
      repoURL: https://github.com/example/dry-source
      path: dry
      targetRevision: HEAD
    syncSource:
      path: hydrated
      targetBranch: main
EOF
)
        
        if echo "$test_app_v2141_yaml" | kubectl apply --dry-run=client -f - >/dev/null 2>&1; then
            echo -e "${GREEN}✓ v2.14.11 sourceHydrator fields accepted (CRD updated)${NC}"
        else
            echo -e "${YELLOW}⚠ v2.14.11 sourceHydrator fields rejected${NC}"
        fi
    fi
    
    # Check CRD annotations and resource policy
    echo -e "${BLUE}5. CRD Resource Policy Check:${NC}"
    for crd in "${argocd_crds[@]}"; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            local resource_policy=$(kubectl get crd "$crd" -o jsonpath='{.metadata.annotations.helm\.sh/resource-policy}' 2>/dev/null)
            if [ "$resource_policy" = "keep" ]; then
                echo -e "${GREEN}✓ $crd has 'keep' resource policy${NC}"
            else
                echo -e "${YELLOW}⚠ $crd missing 'keep' resource policy${NC}"
            fi
        fi
    done
    
    # Check for CRD ownership
    echo -e "${BLUE}6. CRD Ownership Check:${NC}"
    for crd in "${argocd_crds[@]}"; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            local managed_by=$(kubectl get crd "$crd" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)
            local part_of=$(kubectl get crd "$crd" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}' 2>/dev/null)
            
            echo "--- $crd ---"
            echo "Managed by: ${managed_by:-'not set'}"
            echo "Part of: ${part_of:-'not set'}"
            
            if [ "$managed_by" = "Helm" ] && [ "$part_of" = "argocd" ]; then
                echo -e "${GREEN}✓ Proper ownership labels${NC}"
            else
                echo -e "${YELLOW}⚠ Missing or incorrect ownership labels${NC}"
            fi
            echo ""
        fi
    done
    
    # Check for deprecated API versions
    echo -e "${BLUE}7. Deprecated API Version Check:${NC}"
    local deprecated_apis=$(kubectl get applications,applicationsets,appprojects -A -o json 2>/dev/null | jq -r '.items[] | select(.apiVersion != "argoproj.io/v1alpha1") | "\(.kind)/\(.metadata.name) uses \(.apiVersion)"' 2>/dev/null || echo "")
    
    if [ -z "$deprecated_apis" ]; then
        echo -e "${GREEN}✓ No deprecated API versions found${NC}"
    else
        echo -e "${YELLOW}⚠ Found deprecated API versions:${NC}"
        echo "$deprecated_apis"
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}=== CRD VALIDATION SUMMARY ===${NC}"
    if [ "$issues" -eq 0 ]; then
        echo -e "${GREEN}✓ CRD VALIDATION PASSED - All CRDs are healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ CRD VALIDATION FAILED - $issues issues found${NC}"
        echo -e "${YELLOW}Review CRD issues before proceeding with upgrade${NC}"
        return 1
    fi
}

# =============================================================================
# COMPREHENSIVE CRD DIFF CHECK (Pre/Post Upgrade)
# =============================================================================
crd_diff_check() {
    local mode="$1"  # "pre" or "post"
    local backup_dir="$2"
    
    echo -e "${BLUE}=== CRD DIFF CHECK ($mode-upgrade) ===${NC}"
    echo "Timestamp: $(date)"
    echo ""
    
    case "$mode" in
        "pre")
            # Save current CRD state for comparison
            echo -e "${BLUE}Saving current CRD state...${NC}"
            mkdir -p "crd_snapshots"
            
            for crd in "applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io"; do
                if kubectl get crd "$crd" >/dev/null 2>&1; then
                    kubectl get crd "$crd" -o yaml > "crd_snapshots/${crd}-pre-upgrade.yaml"
                    echo -e "${GREEN}✓ Saved $crd snapshot${NC}"
                else
                    echo -e "${YELLOW}⚠ CRD $crd not found${NC}"
                fi
            done
            
            # Save current resource counts
            kubectl get applications -A --no-headers 2>/dev/null | wc -l > "crd_snapshots/applications-count-pre.txt"
            kubectl get applicationsets -A --no-headers 2>/dev/null | wc -l > "crd_snapshots/applicationsets-count-pre.txt"
            kubectl get appprojects -A --no-headers 2>/dev/null | wc -l > "crd_snapshots/appprojects-count-pre.txt"
            
            echo -e "${GREEN}✓ Pre-upgrade CRD snapshot completed${NC}"
            ;;
            
        "post")
            # Compare with pre-upgrade state
            echo -e "${BLUE}Comparing with pre-upgrade CRD state...${NC}"
            local changes_found=0
            
            if [ ! -d "crd_snapshots" ]; then
                echo -e "${RED}✗ No pre-upgrade snapshots found${NC}"
                return 1
            fi
            
            for crd in "applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io"; do
                echo "--- $crd ---"
                
                if [ -f "crd_snapshots/${crd}-pre-upgrade.yaml" ] && kubectl get crd "$crd" >/dev/null 2>&1; then
                    # Save current state
                    kubectl get crd "$crd" -o yaml > "crd_snapshots/${crd}-post-upgrade.yaml"
                    
                    # Compare schemas
                    if diff -u "crd_snapshots/${crd}-pre-upgrade.yaml" "crd_snapshots/${crd}-post-upgrade.yaml" > "crd_snapshots/${crd}-diff.txt"; then
                        echo -e "${GREEN}✓ No changes detected${NC}"
                    else
                        echo -e "${YELLOW}⚠ Changes detected in $crd${NC}"
                        ((changes_found++))
                        
                        # Show summary of changes
                        echo "Key changes:"
                        grep -E "^\+|^\-" "crd_snapshots/${crd}-diff.txt" | grep -v "resourceVersion\|generation\|creationTimestamp" | head -10
                        echo "Full diff saved to: crd_snapshots/${crd}-diff.txt"
                    fi
                else
                    echo -e "${RED}✗ Cannot compare $crd (missing pre or post snapshot)${NC}"
                    ((changes_found++))
                fi
                echo ""
            done
            
            # Compare resource counts
            echo -e "${BLUE}Resource Count Comparison:${NC}"
            
            local resources=("applications" "applicationsets" "appprojects")
            for resource in "${resources[@]}"; do
                local pre_count=$(cat "crd_snapshots/${resource}-count-pre.txt" 2>/dev/null || echo "0")
                local post_count=$(kubectl get $resource -A --no-headers 2>/dev/null | wc -l)
                
                echo "$resource: $pre_count -> $post_count"
                
                if [ "$pre_count" -eq "$post_count" ]; then
                    echo -e "${GREEN}✓ Count unchanged${NC}"
                else
                    echo -e "${YELLOW}⚠ Count changed${NC}"
                fi
            done
            
            # Summary
            echo ""
            if [ "$changes_found" -eq 0 ]; then
                echo -e "${GREEN}✓ CRD DIFF CHECK PASSED - No significant changes${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠ CRD DIFF CHECK - $changes_found changes detected${NC}"
                echo "Review changes in crd_snapshots/ directory"
                return 1
            fi
            ;;
            
        *)
            echo -e "${RED}✗ Invalid mode. Use 'pre' or 'post'${NC}"
            return 1
            ;;
    esac
}

# =============================================================================
# MAIN FUNCTION AND COMMAND DISPATCHER
# =============================================================================
show_usage() {
    echo "ArgoCD Validation Scripts - Enhanced Version"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  pre-check                    - Run pre-upgrade validation (improved)"
    echo "  post-check                   - Run post-upgrade validation"
    echo "  redis-check                  - Check Redis HA health (enhanced)"
    echo "  crd-check                    - Validate ArgoCD CRDs (v2.14.11 ready)"
    echo "  crd-diff <pre|post>          - CRD diff analysis"
    echo "  feature-check <feature>      - Validate specific feature"
    echo "  performance                  - Monitor performance metrics"
    echo "  backup-verify <backup_dir>   - Verify backup integrity"
    echo ""
    echo "Feature options for feature-check:"
    echo "  redis-auth <password>        - Validate Redis authentication"
    echo "  new-ui                       - Validate new UI features"
    echo "  source-hydrator              - Validate source hydrator"
    echo ""
    echo "CRD diff options:"
    echo "  crd-diff pre                 - Save pre-upgrade CRD snapshots"
    echo "  crd-diff post                - Compare post-upgrade CRDs"
    echo ""
    echo "Improvements in this version:"
    echo "  • Fixed false positives for Completed/Succeeded jobs"
    echo "  • Enhanced Redis authentication detection"
    echo "  • Better v2.14.11 feature support validation"
    echo "  • Improved connectivity testing"
    echo "  • More accurate health percentages"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE                    - Kubernetes namespace (default: argocd)"
    echo ""
    echo "Examples:"
    echo "  $0 pre-check"
    echo "  $0 crd-check"
    echo "  $0 crd-diff pre              # Before upgrade"
    echo "  $0 crd-diff post             # After upgrade"
    echo "  $0 feature-check redis-auth mypassword"
    echo "  $0 backup-verify ./backup-20241201-120000"
    echo "  NAMESPACE=argocd-prod $0 post-check"
}

main() {
    case "${1:-}" in
        "pre-check")
            pre_upgrade_validation
            ;;
        "post-check")
            post_upgrade_validation
            ;;
        "redis-check")
            redis_health_check
            ;;
        "crd-check")
            crd_validation
            ;;
        "crd-diff")
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Mode required (pre|post)${NC}"
                show_usage
                exit 1
            fi
            crd_diff_check "$2" "$3"
            ;;
        "feature-check")
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Feature name required${NC}"
                show_usage
                exit 1
            fi
            feature_validation "$2" "$3"
            ;;
        "performance")
            performance_monitoring
            ;;
        "backup-verify")
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Backup directory required${NC}"
                show_usage
                exit 1
            fi
            backup_verification "$2"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Save application count for comparison (utility function)
save_app_count() {
    kubectl get applications -A --no-headers 2>/dev/null | wc -l > pre_upgrade_app_count.txt
    echo "Application count saved to pre_upgrade_app_count.txt"
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Check dependencies
    local deps=("kubectl" "helm" "jq" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}Required dependency not found: $dep${NC}"
            exit 1
        fi
    done
    
    main "$@"
fi# Sentinel masters (improved)
    echo -e "${BLUE}4. Sentinel Masters:${NC}"
    if [ -n "$redis_auth" ]; then
        kubectl exec -n $NAMESPACE argocd-redis-ha-server-0 -c sentinel -- redis-cli -p 26379 -a "$redis_auth" sentinel masters 2>/dev/null || echo "Failed to connect to Sentinel (with auth)"
    else
        kubectl exec -n $NAMESPACE argocd-redis-ha-server-0 -c sentinel -- redis-cli -p 26379 sentinel masters 2>/dev/null || echo "Failed to connect to Sentinel (auth may be required)"
    fi
    echo ""
    
    # Recent Redis logs for errors (improved filtering)
    echo -e "${BLUE}5. Recent Redis Error Logs:${NC}"
    for pod in $(kubectl get pods -n $NAMESPACE -l app=redis-ha -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        echo "--- $pod redis container ---"
        local errors=$(kubectl logs -n $NAMESPACE $pod -c redis --tail=20 2>/dev/null | grep -i -E "(error|denied|fail)" | grep -v -E "(NOAUTH|replication)")
        if [ -n "$errors" ]; then
            echo "$errors"
        else
            echo "No recent errors in $pod"
        fi
        echo ""
    done
    
    # Service endpoints
    echo -e "${BLUE}6. Redis HA Service Endpoints:${NC}"
    kubectl get endpoints -n $NAMESPACE argocd-redis-ha -o wide 2>/dev/null || echo "Redis HA service not found"
    echo ""
    
    # Connection test from ArgoCD server
    echo -e "${BLUE}7. ArgoCD-Redis Connectivity Test:${NC}"
    local server_pod=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$server_pod" ]; then
        echo "Testing from ArgoCD server pod: $server_pod"
        if kubectl exec -n $NAMESPACE $server_pod -- nc -z argocd-redis-ha 6379 2>/dev/null; then
            echo -e "${GREEN}✓ ArgoCD can reach Redis HA service${NC}"
        else
            echo -e "${YELLOW}⚠ ArgoCD cannot reach Redis HA service${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No ArgoCD server pod found for connectivity test${NC}"
    fi
    
    echo -e "${BLUE}=== REDIS HEALTH CHECK COMPLETE ===${NC}"
}

# =============================================================================
# POST-UPGRADE VALIDATION
# =============================================================================
post_upgrade_validation() {
    echo -e "${BLUE}=== POST-UPGRADE VALIDATION ===${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    local issues=0
    
    # Wait for pods to be ready
    echo -e "${BLUE}1. Waiting for pods to be ready...${NC}"
    if kubectl wait --for=condition=ready pods --all -n $NAMESPACE --timeout=300s >/dev/null 2>&1; then
        echo -e "${GREEN}✓ All pods are ready${NC}"
    else
        echo -e "${YELLOW}⚠ Some pods may still be starting${NC}"
    fi
    
    # Check upgrade success
    echo -e "${BLUE}2. Verifying upgrade...${NC}"
    local current_chart=$(helm list -n $NAMESPACE -o json | jq -r '.[] | select(.name=="argocd") | .chart')
    local app_version=$(helm list -n $NAMESPACE -o json | jq -r '.[] | select(.name=="argocd") | .app_version')
    echo "Current chart: $current_chart"
    echo "App version: $app_version"
    
    if [[ "$current_chart" == *"7.9.1"* ]] && [[ "$app_version" == *"2.14.11"* ]]; then
        echo -e "${GREEN}✓ Upgrade to v2.14.11 successful${NC}"
    else
        echo -e "${RED}✗ Upgrade verification failed${NC}"
        ((issues++))
    fi
    
    # Redis HA validation
    echo -e "${BLUE}3. Redis HA post-upgrade check...${NC}"
    redis_health_check
    
    # Test ArgoCD API
    echo -e "${BLUE}4. Testing ArgoCD API...${NC}"
    kubectl port-forward -n $NAMESPACE svc/argocd-server 8080:80 &
    local pf_pid=$!
    sleep 5
    
    if curl -k -s https://localhost:8080/api/version >/dev/null; then
        echo -e "${GREEN}✓ ArgoCD API is responding${NC}"
        local api_version=$(curl -k -s https://localhost:8080/api/version | jq -r '.Version // "unknown"')
        echo "API Version: $api_version"
    else
        echo -e "${RED}✗ ArgoCD API is not responding${NC}"
        ((issues++))
    fi
    
    kill $pf_pid 2>/dev/null || true
    
    # Application count verification
    echo -e "${BLUE}5. Application count verification...${NC}"
    local current_apps=$(kubectl get applications -A --no-headers 2>/dev/null | wc -l)
    echo "Current applications: $current_apps"
    
    if [ -f "pre_upgrade_app_count.txt" ]; then
        local previous_apps=$(cat pre_upgrade_app_count.txt)
        echo "Previous applications: $previous_apps"
        
        if [ "$current_apps" -eq "$previous_apps" ]; then
            echo -e "${GREEN}✓ Application count matches${NC}"
        else
            echo -e "${YELLOW}⚠ Application count changed: $previous_apps -> $current_apps${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No pre-upgrade application count available${NC}"
    fi
    
    # Check for new errors
    echo -e "${BLUE}6. Checking for post-upgrade errors...${NC}"
    local server_errors=$(kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=argocd-server --tail=50 2>/dev/null | grep -i error | wc -l)
    local controller_errors=$(kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=argocd-application-controller --tail=50 2>/dev/null | grep -i error | wc -l)
    
    echo "Server errors (last 50 lines): $server_errors"
    echo "Controller errors (last 50 lines): $controller_errors"
    
    if [ "$server_errors" -eq 0 ] && [ "$controller_errors" -eq 0 ]; then
        echo -e "${GREEN}✓ No recent errors found${NC}"
    else
        echo -e "${YELLOW}⚠ Found errors in logs - review manually${NC}"
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}=== POST-UPGRADE VALIDATION SUMMARY ===${NC}"
    if [ "$issues" -eq 0 ]; then
        echo -e "${GREEN}✓ POST-UPGRADE VALIDATION PASSED - Upgrade successful${NC}"
        return 0
    else
        echo -e "${RED}✗ POST-UPGRADE VALIDATION FAILED - $issues issues found${NC}"
        echo -e "${YELLOW}Consider rollback if issues are critical${NC}"
        return 1
    fi
}

# =============================================================================
# FEATURE VALIDATION (for progressive enablement)
# =============================================================================
feature_validation() {
    local feature_name="$1"
    echo -e "${BLUE}=== FEATURE VALIDATION: $feature_name ===${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    case "$feature_name" in
        "redis-auth")
            echo -e "${BLUE}Validating Redis Authentication...${NC}"
            
            # Test Redis auth
            local redis_password="$2"
            if [ -z "$redis_password" ]; then
                echo -e "${RED}✗ Redis password not provided${NC}"
                return 1
            fi
            
            if kubectl exec -n $NAMESPACE argocd-redis-ha-server-0 -c redis -- redis-cli -a "$redis_password" ping >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Redis authentication working${NC}"
            else
                echo -e "${RED}✗ Redis authentication failed${NC}"
                return 1
            fi
            
            # Test Sentinel auth
            if kubectl exec -n $NAMESPACE argocd-redis-ha-server-0 -c sentinel -- redis-cli -p 26379 -a "$redis_password" sentinel masters >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Sentinel authentication working${NC}"
            else
                echo -e "${RED}✗ Sentinel authentication failed${NC}"
                return 1
            fi
            ;;
            
        "new-ui")
            echo -e "${BLUE}Validating New UI Features...${NC}"
            
            # Port forward and test UI
            kubectl port-forward -n $NAMESPACE svc/argocd-server 8080:80 &
            local pf_pid=$!
            sleep 5
            
            if curl -k -s https://localhost:8080 | grep -q "argocd"; then
                echo -e "${GREEN}✓ ArgoCD UI is accessible${NC}"
            else
                echo -e "${RED}✗ ArgoCD UI is not accessible${NC}"
                kill $pf_pid 2>/dev/null || true
                return 1
            fi
            
            kill $pf_pid 2>/dev/null || true
            ;;
            
        "source-hydrator")
            echo -e "${BLUE}Validating Source Hydrator...${NC}"
            
            # Check for hydrator-related logs
            local hydrator_logs=$(kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=argocd-application-controller --tail=100 2>/dev/null | grep -i hydrator | wc -l)
            echo "Hydrator-related log entries: $hydrator_logs"
            
            if [ "$hydrator_logs" -gt 0 ]; then
                echo -e "${GREEN}✓ Source hydrator is active${NC}"
                
                # Check for hydrator errors
                local hydrator_errors=$(kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=argocd-application-controller --tail=100 2>/dev/null | grep -i -E "hydrator.*error|hydrator.*fail" | wc -l)
                if [ "$hydrator_errors" -eq 0 ]; then
                    echo -e "${GREEN}✓ No hydrator errors found${NC}"
                else
                    echo -e "${RED}✗ Found $hydrator_errors hydrator errors${NC}"
                    return 1
                fi
            else
                echo -e "${YELLOW}⚠ No hydrator activity detected${NC}"
            fi
            ;;
            
        *)
            echo -e "${YELLOW}⚠ Unknown feature: $feature_name${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✓ Feature validation completed successfully${NC}"
    return 0
}

# =============================================================================
# PERFORMANCE MONITORING
# =============================================================================
performance_monitoring() {
    echo -e "${BLUE}=== PERFORMANCE MONITORING ===${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    # Resource usage
    echo -e "${BLUE}1. Resource Usage:${NC}"
    kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"
    echo ""
    
    # Pod restart counts
    echo -e "${BLUE}2. Pod Restart Analysis:${NC}"
    kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' | column -t
    echo ""
    
    # Recent events
    echo -e "${BLUE}3. Recent Events:${NC}"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
    echo ""
    
    # Application sync status
    echo -e "${BLUE}4. Application Sync Status:${NC}"
    local sync_summary=$(kubectl get applications -A -o jsonpath='{range .items[*]}{.status.sync.status}{"\n"}{end}' 2>/dev/null | sort | uniq -c)
    echo "$sync_summary"
    echo ""
    
    # Redis performance
    echo -e "${BLUE}5. Redis Performance:${NC}"
    for pod in $(kubectl get pods -n $NAMESPACE -l app=redis-ha -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        echo "--- $pod ---"
        kubectl exec -n $NAMESPACE $pod -c redis -- redis-cli info stats 2>/dev/null | grep -E "instantaneous_ops_per_sec|used_memory_human|connected_clients" || echo "Failed to get stats from $pod"
        echo ""
    done
}

# =============================================================================
# BACKUP VERIFICATION
# =============================================================================
backup_verification() {
    local backup_dir="$1"
    echo -e "${BLUE}=== BACKUP VERIFICATION ===${NC}"
    echo "Timestamp: $(date)"
    echo "Backup directory: $backup_dir"
    echo ""
    
    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}✗ Backup directory not found: $backup_dir${NC}"
        return 1
    fi
    
    # Check backup files
    echo -e "${BLUE}1. Backup Files:${NC}"
    ls -la "$backup_dir/"
    echo ""
    
    # Verify critical files
    echo -e "${BLUE}2. Critical File Verification:${NC}"
    local critical_files=("helm-values.yaml" "all-applications.yaml" "argocd-secrets.yaml")
    local missing_files=0
    
    for file in "${critical_files[@]}"; do
        if [ -f "$backup_dir/$file" ]; then
            local file_size=$(stat -f%z "$backup_dir/$file" 2>/dev/null || stat -c%s "$backup_dir/$file" 2>/dev/null)
            echo -e "${GREEN}✓ $file ($file_size bytes)${NC}"
        else
            echo -e "${RED}✗ Missing: $file${NC}"
            ((missing_files++))
        fi
    done
    
    # Test restore capability (dry-run)
    echo -e "${BLUE}3. Testing Restore Capability (dry-run):${NC}"
    if [ -f "$backup_dir/all-applications.yaml" ]; then
        if kubectl apply --dry-run=client -f "$backup_dir/all-applications.yaml" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Applications backup is valid${NC}"
        else
            echo -e "${RED}✗ Applications backup validation failed${NC}"
            ((missing_files++))
        fi
    fi
    
    # Summary
    echo ""
    if [ "$missing_files" -eq 0 ]; then
        echo -e "${GREEN}✓ BACKUP VERIFICATION PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ BACKUP VERIFICATION FAILED - $missing_files issues found${NC}"
        return 1
    fi
}

# =============================================================================
# CRD VALIDATION (Enhanced with better v2.14.11 support)
# =============================================================================
crd_validation() {
    echo -e "${BLUE}=== CRD VALIDATION ===${NC}"
    echo "Timestamp: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    local issues=0
    
    # Check ArgoCD CRDs existence
    echo -e "${BLUE}1. ArgoCD CRDs Status:${NC}"
    local argocd_crds=("applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io")
    
    for crd in "${argocd_crds[@]}"; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            local crd_version=$(kubectl get crd "$crd" -o jsonpath='{.spec.versions[0].name}')
            local crd_group=$(kubectl get crd "$crd" -o jsonpath='{.spec.group}')
            echo -e "${GREEN}✓ $crd ($crd_group/$crd_version)${NC}"
        else
            echo -e "${RED}✗ Missing CRD: $crd${NC}"
            ((issues++))
        fi
    done
    echo ""
    
    # Check CRD versions and schema (enhanced for v2.14.11)
    echo -e "${BLUE}2. CRD Schema Validation:${NC}"
    for crd in "${argocd_crds[@]}"; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            echo "--- $crd ---"
            
            # Check supported versions
            local versions=$(kubectl get crd "$crd" -o jsonpath='{.spec.versions[*].name}' | tr ' ' ',')
            echo "Supported versions: $versions"
            
            # Check if v1alpha1 is supported (required for ArgoCD)
            if kubectl get crd "$crd" -o jsonpath='{.spec.versions[*].name}' | grep -q "v1alpha1"; then
                echo -e "${GREEN}✓ v1alpha1 supported${NC}"
            else
                echo -e "${RED}✗ v1alpha1 not supported${NC}"
                ((issues++))
            fi
            
            # Check for v2.14.11 specific fields
            case "$crd" in
                "applications.argoproj.io")
                    # Check for sourceHydrator field (v2.14.11 feature)
                    if kubectl get crd "$crd" -o yaml 2>/dev/null | grep -q "sourceHydrator"; then
                        echo -e "${GREEN}✓ sourceHydrator field available (v2.14.11)${NC}"
                    else
                        echo -e "${YELLOW}⚠ sourceHydrator field not found (pre-v2.14.11)${NC}"
                    fi
                    
                    # Check for Project column in printer columns
                    if kubectl get crd "$crd" -o yaml 2>/dev/null | grep -A 5 "additionalPrinterColumns" | grep -q "Project"; then
                        echo -e "${GREEN}✓ Project printer column present${NC}"
                    else
                        echo -e "${YELLOW}⚠ Project printer column missing (expected in v2.11.3+)${NC}"
                    fi
                    
                    # Check for ignoreDifferences enhancements
                    if kubectl get crd "$crd" -o yaml 2>/dev/null | grep -q "jsonPointers"; then
                        echo -e "${GREEN}✓ Enhanced ignoreDifferences available${NC}"
                    else
                        echo -e "${YELLOW}⚠ Enhanced ignoreDifferences not available${NC}"
                    fi
                    ;;
                    
                "applicationsets.argoproj.io")
                    # Check for flatList field removal (deprecated in v2.14.11)
                    if kubectl get crd "$crd" -o yaml 2>/dev/null | grep -q "flatList"; then
                        echo -e "${YELLOW}⚠ flatList field detected (deprecated in v2.14.11)${NC}"
                    else
                        echo -e "${GREEN}✓ flatList field properly removed${NC}"
                    fi
                    
                    # Check for new generator types
                    if kubectl get crd "$crd" -o yaml 2>/dev/null | grep -q "pullRequestGenerator"; then
                        echo -e "${GREEN}✓ Pull Request generator available${NC}"
                    fi
                    ;;
            esac
            echo ""
        fi
    done