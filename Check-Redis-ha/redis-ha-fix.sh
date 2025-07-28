#!/bin/bash

# ArgoCD Redis HA Troubleshooting Script
# Author: DevOps Assistant
# Description: Diagnoses and fixes Redis HA issues in ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="argocd"
REDIS_SECRET="argocd-redis"
STATEFULSET="argocd-redis-ha-server"

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

print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE} ArgoCD Redis HA Troubleshooter${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
    echo
}

# Get Redis authentication
get_redis_auth() {
    log_info "Getting Redis authentication..."
    REDIS_AUTH=$(kubectl get secret $REDIS_SECRET -n $NAMESPACE -o jsonpath="{.data.auth}" 2>/dev/null | base64 -d)
    if [ $? -eq 0 ] && [ ! -z "$REDIS_AUTH" ]; then
        log_success "Redis auth retrieved successfully"
    else
        log_warning "Could not retrieve Redis auth, some operations may fail"
        REDIS_AUTH=""
    fi
    echo
}

# Diagnosis functions
check_pod_status() {
    log_info "Checking Redis HA pod status..."
    echo
    kubectl get pods -n $NAMESPACE -l app=redis-ha -o wide
    echo
}

check_problematic_pods() {
    log_info "Identifying problematic pods..."
    
    PROBLEM_PODS=$(kubectl get pods -n $NAMESPACE -l app=redis-ha --no-headers | grep -E "(CrashLoopBackOff|Error|Pending)" | awk '{print $1}' || true)
    
    if [ ! -z "$PROBLEM_PODS" ]; then
        log_warning "Found problematic pods:"
        echo "$PROBLEM_PODS"
        echo
        return 0
    else
        log_success "No problematic pods found"
        echo
        return 1
    fi
}

describe_problematic_pods() {
    if [ ! -z "$PROBLEM_PODS" ]; then
        log_info "Describing problematic pods..."
        for pod in $PROBLEM_PODS; do
            echo -e "${YELLOW}--- Pod: $pod ---${NC}"
            kubectl describe pod $pod -n $NAMESPACE | grep -A 10 -B 5 -E "(State:|Events:|Conditions:)"
            echo
        done
    fi
}

check_redis_logs() {
    if [ ! -z "$PROBLEM_PODS" ]; then
        log_info "Getting logs from problematic pods..."
        for pod in $PROBLEM_PODS; do
            echo -e "${YELLOW}--- Logs for: $pod ---${NC}"
            kubectl logs $pod -n $NAMESPACE -c redis --tail=20 || log_warning "Could not get logs for $pod"
            echo
        done
    fi
}

check_redis_master_status() {
    log_info "Checking Redis master status..."
    
    # Try to find the master
    REDIS_PODS=$(kubectl get pods -n $NAMESPACE -l app=redis-ha --no-headers | grep Running | awk '{print $1}')
    
    for pod in $REDIS_PODS; do
        echo -e "${YELLOW}--- Checking $pod ---${NC}"
        if [ ! -z "$REDIS_AUTH" ]; then
            kubectl exec $pod -n $NAMESPACE -c redis -- redis-cli -a "$REDIS_AUTH" INFO replication 2>/dev/null || log_warning "Could not connect to $pod"
        else
            kubectl exec $pod -n $NAMESPACE -c redis -- redis-cli INFO replication 2>/dev/null || log_warning "Could not connect to $pod"
        fi
        echo
    done
}

check_configmaps() {
    log_info "Checking Redis HA configuration..."
    
    echo -e "${YELLOW}--- Redis ConfigMap ---${NC}"
    kubectl get configmap argocd-redis-ha-configmap -n $NAMESPACE -o yaml | grep -A 20 "redis.conf:"
    echo
}

check_resources() {
    log_info "Checking resource usage and limits..."
    
    echo -e "${YELLOW}--- Pod Resource Usage ---${NC}"
    kubectl top pods -n $NAMESPACE -l app=redis-ha 2>/dev/null || log_warning "Metrics server not available"
    echo
    
    echo -e "${YELLOW}--- Resource Limits ---${NC}"
    kubectl get pods -n $NAMESPACE -l app=redis-ha -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}' | column -t
    echo
}

# Repair functions
delete_problematic_pods() {
    if [ ! -z "$PROBLEM_PODS" ]; then
        read -p "Do you want to delete problematic pods? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting problematic pods..."
            for pod in $PROBLEM_PODS; do
                log_info "Deleting pod: $pod"
                kubectl delete pod $pod -n $NAMESPACE --grace-period=0 --force
            done
            log_success "Problematic pods deleted"
        else
            log_info "Skipping pod deletion"
        fi
        echo
    fi
}

restart_statefulset() {
    read -p "Do you want to restart the Redis HA StatefulSet? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restarting Redis HA StatefulSet..."
        kubectl rollout restart statefulset $STATEFULSET -n $NAMESPACE
        
        log_info "Waiting for rollout to complete..."
        kubectl rollout status statefulset $STATEFULSET -n $NAMESPACE --timeout=300s
        
        log_success "StatefulSet restart completed"
    else
        log_info "Skipping StatefulSet restart"
    fi
    echo
}

scale_down_and_up() {
    read -p "Do you want to scale down and up the StatefulSet? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Scaling down StatefulSet to 0..."
        kubectl scale statefulset $STATEFULSET -n $NAMESPACE --replicas=0
        
        log_info "Waiting for pods to terminate..."
        sleep 30
        
        log_info "Scaling up StatefulSet to 3..."
        kubectl scale statefulset $STATEFULSET -n $NAMESPACE --replicas=3
        
        log_info "Waiting for pods to be ready..."
        kubectl wait --for=condition=ready pod -l app=redis-ha -n $NAMESPACE --timeout=300s
        
        log_success "Scale operation completed"
    else
        log_info "Skipping scale operation"
    fi
    echo
}

verify_fix() {
    log_info "Verifying the fix..."
    echo
    
    log_info "Current pod status:"
    kubectl get pods -n $NAMESPACE -l app=redis-ha
    echo
    
    log_info "Checking Redis cluster status..."
    REDIS_PODS=$(kubectl get pods -n $NAMESPACE -l app=redis-ha --no-headers | grep Running | awk '{print $1}')
    
    for pod in $REDIS_PODS; do
        echo -e "${YELLOW}--- $pod Status ---${NC}"
        if [ ! -z "$REDIS_AUTH" ]; then
            kubectl exec $pod -n $NAMESPACE -c redis -- redis-cli -a "$REDIS_AUTH" ping 2>/dev/null && log_success "$pod is responding" || log_error "$pod is not responding"
        else
            kubectl exec $pod -n $NAMESPACE -c redis -- redis-cli ping 2>/dev/null && log_success "$pod is responding" || log_error "$pod is not responding"
        fi
    done
    echo
}

# Monitoring function
monitor_pods() {
    log_info "Monitoring pod status (Press Ctrl+C to stop)..."
    echo
    
    while true; do
        clear
        echo -e "${BLUE}Redis HA Pod Monitor - $(date)${NC}"
        echo
        kubectl get pods -n $NAMESPACE -l app=redis-ha -o wide
        echo
        sleep 5
    done
}

# Generate report
generate_report() {
    REPORT_FILE="redis-ha-report-$(date +%Y%m%d-%H%M%S).txt"
    log_info "Generating diagnostic report: $REPORT_FILE"
    
    {
        echo "ArgoCD Redis HA Diagnostic Report"
        echo "Generated: $(date)"
        echo "Namespace: $NAMESPACE"
        echo "================================="
        echo
        
        echo "Pod Status:"
        kubectl get pods -n $NAMESPACE -l app=redis-ha -o wide
        echo
        
        echo "StatefulSet Status:"
        kubectl get statefulset $STATEFULSET -n $NAMESPACE -o wide
        echo
        
        echo "Events:"
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep redis
        echo
        
        if [ ! -z "$PROBLEM_PODS" ]; then
            echo "Problematic Pods Details:"
            for pod in $PROBLEM_PODS; do
                echo "--- $pod ---"
                kubectl describe pod $pod -n $NAMESPACE
                echo
            done
        fi
    } > "$REPORT_FILE"
    
    log_success "Report saved to: $REPORT_FILE"
    echo
}

# Main menu
show_menu() {
    echo -e "${BLUE}Choose an option:${NC}"
    echo "1) Full Diagnosis"
    echo "2) Quick Fix (Delete problematic pods)"
    echo "3) Restart StatefulSet"
    echo "4) Scale Down/Up StatefulSet"
    echo "5) Monitor Pods"
    echo "6) Generate Report"
    echo "7) Exit"
    echo
}

main() {
    print_header
    check_prerequisites
    get_redis_auth
    
    while true; do
        show_menu
        read -p "Enter your choice [1-7]: " choice
        echo
        
        case $choice in
            1)
                log_info "Starting full diagnosis..."
                check_pod_status
                if check_problematic_pods; then
                    describe_problematic_pods
                    check_redis_logs
                fi
                check_redis_master_status
                check_configmaps
                check_resources
                echo
                ;;
            2)
                check_problematic_pods
                delete_problematic_pods
                sleep 10
                verify_fix
                ;;
            3)
                restart_statefulset
                verify_fix
                ;;
            4)
                scale_down_and_up
                verify_fix
                ;;
            5)
                monitor_pods
                ;;
            6)
                check_problematic_pods
                generate_report
                ;;
            7)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please choose 1-7."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        echo
    done
}

# Run main function
main "$@"