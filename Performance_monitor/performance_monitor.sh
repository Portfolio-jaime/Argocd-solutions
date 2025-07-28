#!/bin/bash

# =============================================================================
# ArgoCD Performance Monitor
# Real-time monitoring and performance analysis for ArgoCD components
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
MONITOR_DURATION=${MONITOR_DURATION:-300}  # 5 minutes default
SAMPLE_INTERVAL=${SAMPLE_INTERVAL:-10}     # 10 seconds default
REPORT_DIR="./performance_report_$(date +%Y%m%d_%H%M%S)"

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
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}        ArgoCD Performance Monitor${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Namespace: ${ARGOCD_NAMESPACE}${NC}"
    echo -e "${BLUE}Duration: ${MONITOR_DURATION}s${NC}"
    echo -e "${BLUE}Interval: ${SAMPLE_INTERVAL}s${NC}"
    echo
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    local deps=("kubectl" "jq" "curl")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    # Check if metrics-server is available
    if ! kubectl top nodes &>/dev/null; then
        log_warning "metrics-server not available - resource metrics will be limited"
    fi
    
    mkdir -p "$REPORT_DIR"
    log_success "Prerequisites check passed"
}

# Monitor ArgoCD components
monitor_components() {
    log_info "Starting component monitoring..."
    
    local components=("argocd-server" "argocd-application-controller" "argocd-repo-server" "argocd-redis")
    
    {
        echo "# ArgoCD Components Performance Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Component Status Overview"
        echo ""
    } > "$REPORT_DIR/components_performance.md"
    
    for component in "${components[@]}"; do
        log_info "Monitoring $component..."
        
        local pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l "app.kubernetes.io/name=$component" -o name 2>/dev/null | head -5)
        
        if [ -z "$pods" ]; then
            # Try alternative label patterns
            pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l "app=$component" -o name 2>/dev/null | head -5)
        fi
        
        {
            echo "### $component"
            echo ""
            echo "**Pod Status:**"
            echo '```'
            kubectl get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name="$component" 2>/dev/null || \
            kubectl get pods -n "$ARGOCD_NAMESPACE" -l app="$component" 2>/dev/null || \
            echo "No pods found for $component"
            echo '```'
            echo ""
            
            # Resource usage if available
            echo "**Resource Usage:**"
            echo '```'
            kubectl top pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name="$component" 2>/dev/null || \
            kubectl top pods -n "$ARGOCD_NAMESPACE" -l app="$component" 2>/dev/null || \
            echo "Resource metrics not available"
            echo '```'
            echo ""
            
        } >> "$REPORT_DIR/components_performance.md"
    done
}

# Monitor API performance
monitor_api_performance() {
    log_info "Monitoring ArgoCD API performance..."
    
    # Port forward to ArgoCD server
    kubectl port-forward -n "$ARGOCD_NAMESPACE" svc/argocd-server 8080:80 &>/dev/null &
    local pf_pid=$!
    sleep 3
    
    {
        echo "# ArgoCD API Performance Report"
        echo "Generated: $(date)"
        echo ""
        echo "## API Response Times"
        echo ""
    } > "$REPORT_DIR/api_performance.md"
    
    # Test various API endpoints
    local endpoints=(
        "/api/version"
        "/api/v1/applications"
        "/api/v1/projects"
        "/api/v1/repositories"
        "/api/v1/clusters"
    )
    
    echo "| Endpoint | Response Time (ms) | Status |" >> "$REPORT_DIR/api_performance.md"
    echo "|----------|-------------------|--------|" >> "$REPORT_DIR/api_performance.md"
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        local status_code=$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost:8080$endpoint" || echo "000")
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        
        local status_text="❌ Failed"
        if [ "$status_code" = "200" ]; then
            status_text="✅ OK"
        elif [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
            status_text="🔐 Auth Required"
        fi
        
        echo "| $endpoint | $duration | $status_text |" >> "$REPORT_DIR/api_performance.md"
    done
    
    # Kill port forward
    kill $pf_pid 2>/dev/null || true
    
    {
        echo ""
        echo "## API Health Summary"
        echo ""
        echo "- Test performed at: $(date)"
        echo "- All endpoints tested for basic connectivity"
        echo "- Authentication may be required for full access"
    } >> "$REPORT_DIR/api_performance.md"
}

# Monitor resource utilization over time
monitor_resource_utilization() {
    log_info "Starting resource utilization monitoring..."
    
    local samples=$((MONITOR_DURATION / SAMPLE_INTERVAL))
    local sample_count=0
    
    {
        echo "# Resource Utilization Over Time"
        echo "Generated: $(date)"
        echo ""
        echo "Monitoring Duration: ${MONITOR_DURATION}s (${samples} samples)"
        echo ""
        echo "## CPU and Memory Usage"
        echo ""
    } > "$REPORT_DIR/resource_utilization.md"
    
    # Create CSV for data analysis
    echo "timestamp,pod_name,cpu_cores,memory_mb" > "$REPORT_DIR/resource_data.csv"
    
    while [ $sample_count -lt $samples ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        log_info "Sample $((sample_count + 1))/$samples - $timestamp"
        
        # Get resource usage
        if kubectl top pods -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null; then
            kubectl top pods -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | while read -r pod_name cpu memory; do
                # Convert CPU (remove 'm' suffix) and Memory (remove 'Mi' suffix)
                cpu_value=$(echo "$cpu" | sed 's/m$//')
                memory_value=$(echo "$memory" | sed 's/Mi$//')
                
                echo "$timestamp,$pod_name,$cpu_value,$memory_value" >> "$REPORT_DIR/resource_data.csv"
            done
        fi
        
        ((sample_count++))
        
        if [ $sample_count -lt $samples ]; then
            sleep "$SAMPLE_INTERVAL"
        fi
    done
    
    # Generate summary statistics
    {
        echo ""
        echo "## Resource Usage Summary"
        echo ""
        echo "### Top CPU Consumers"
        echo '```'
        if [ -f "$REPORT_DIR/resource_data.csv" ]; then
            tail -n +2 "$REPORT_DIR/resource_data.csv" | \
            awk -F',' '{pod_cpu[$2] += $3; count[$2]++} END {for (pod in pod_cpu) printf "%-30s: %.0f cores avg\n", pod, pod_cpu[pod]/count[pod]}' | \
            sort -k2 -nr | head -5
        fi
        echo '```'
        echo ""
        
        echo "### Top Memory Consumers"
        echo '```'
        if [ -f "$REPORT_DIR/resource_data.csv" ]; then
            tail -n +2 "$REPORT_DIR/resource_data.csv" | \
            awk -F',' '{pod_mem[$2] += $4; count[$2]++} END {for (pod in pod_mem) printf "%-30s: %.0f MB avg\n", pod, pod_mem[pod]/count[pod]}' | \
            sort -k2 -nr | head -5
        fi
        echo '```'
        
    } >> "$REPORT_DIR/resource_utilization.md"
}

# Monitor application sync performance
monitor_sync_performance() {
    log_info "Monitoring application sync performance..."
    
    {
        echo "# Application Sync Performance"
        echo "Generated: $(date)"
        echo ""
        echo "## Sync Status Overview"
        echo ""
    } > "$REPORT_DIR/sync_performance.md"
    
    # Get sync status summary
    local total_apps=$(kubectl get applications -A --no-headers 2>/dev/null | wc -l)
    local synced_apps=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.sync.status == "Synced") | .metadata.name' | wc -l)
    local out_of_sync=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.sync.status == "OutOfSync") | .metadata.name' | wc -l)
    local unknown_sync=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.sync.status == "Unknown") | .metadata.name' | wc -l)
    
    {
        echo "| Status | Count | Percentage |"
        echo "|--------|-------|------------|"
        echo "| Total Applications | $total_apps | 100% |"
        echo "| Synced | $synced_apps | $((synced_apps * 100 / (total_apps > 0 ? total_apps : 1)))% |"
        echo "| OutOfSync | $out_of_sync | $((out_of_sync * 100 / (total_apps > 0 ? total_apps : 1)))% |"
        echo "| Unknown | $unknown_sync | $((unknown_sync * 100 / (total_apps > 0 ? total_apps : 1)))% |"
        echo ""
        
        echo "## Health Status Overview"
        echo ""
    } >> "$REPORT_DIR/sync_performance.md"
    
    # Get health status summary
    local healthy_apps=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.health.status == "Healthy") | .metadata.name' | wc -l)
    local degraded_apps=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.health.status == "Degraded") | .metadata.name' | wc -l)
    local progressing_apps=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.health.status == "Progressing") | .metadata.name' | wc -l)
    
    {
        echo "| Health Status | Count | Percentage |"
        echo "|---------------|-------|------------|"
        echo "| Healthy | $healthy_apps | $((healthy_apps * 100 / (total_apps > 0 ? total_apps : 1)))% |"
        echo "| Degraded | $degraded_apps | $((degraded_apps * 100 / (total_apps > 0 ? total_apps : 1)))% |"
        echo "| Progressing | $progressing_apps | $((progressing_apps * 100 / (total_apps > 0 ? total_apps : 1)))% |"
        echo ""
        
        echo "## Recent Sync Operations"
        echo ""
    } >> "$REPORT_DIR/sync_performance.md"
    
    # Get recent sync operations
    {
        echo "| Application | Namespace | Last Sync | Status | Duration |"
        echo "|-------------|-----------|-----------|--------|----------|"
        
        kubectl get applications -A -o json 2>/dev/null | \
        jq -r '.items[] | 
        "\(.metadata.namespace),\(.metadata.name),\(.status.operationState.finishedAt // "N/A"),\(.status.sync.status),\(.status.operationState.operation.sync.syncOptions // [])"' | \
        head -10 | \
        while IFS=',' read -r namespace name finished_at status options; do
            echo "| $name | $namespace | $finished_at | $status | - |"
        done
        
    } >> "$REPORT_DIR/sync_performance.md"
}

# Monitor Redis performance
monitor_redis_performance() {
    log_info "Monitoring Redis performance..."
    
    {
        echo "# Redis Performance Monitor"
        echo "Generated: $(date)"
        echo ""
        echo "## Redis Cluster Status"
        echo ""
    } > "$REPORT_DIR/redis_performance.md"
    
    # Get Redis pods
    local redis_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l app=redis-ha -o name 2>/dev/null)
    
    if [ -z "$redis_pods" ]; then
        {
            echo "❌ No Redis HA pods found"
            echo ""
            echo "Checking for single Redis instance..."
        } >> "$REPORT_DIR/redis_performance.md"
        
        redis_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=redis -o name 2>/dev/null)
    fi
    
    if [ -n "$redis_pods" ]; then
        {
            echo "**Redis Pods Status:**"
            echo '```'
            kubectl get pods -n "$ARGOCD_NAMESPACE" -l app=redis-ha 2>/dev/null || \
            kubectl get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=redis 2>/dev/null
            echo '```'
            echo ""
            
            echo "## Redis Performance Metrics"
            echo ""
        } >> "$REPORT_DIR/redis_performance.md"
        
        # Get Redis stats from each pod
        local pod_count=0
        echo "$redis_pods" | while read -r pod; do
            pod_name=$(echo "$pod" | sed 's/pod\///')
            ((pod_count++))
            
            {
                echo "### $pod_name"
                echo ""
                echo "**Connection Stats:**"
                echo '```'
                kubectl exec -n "$ARGOCD_NAMESPACE" "$pod_name" -c redis -- redis-cli info clients 2>/dev/null || \
                echo "Could not retrieve Redis stats"
                echo '```'
                echo ""
                
                echo "**Memory Usage:**"
                echo '```'
                kubectl exec -n "$ARGOCD_NAMESPACE" "$pod_name" -c redis -- redis-cli info memory 2>/dev/null | \
                grep -E "used_memory_human|used_memory_peak_human|mem_fragmentation_ratio" || \
                echo "Could not retrieve memory stats"
                echo '```'
                echo ""
                
                echo "**Performance Stats:**"
                echo '```'
                kubectl exec -n "$ARGOCD_NAMESPACE" "$pod_name" -c redis -- redis-cli info stats 2>/dev/null | \
                grep -E "instantaneous_ops_per_sec|total_commands_processed|keyspace" || \
                echo "Could not retrieve performance stats"
                echo '```'
                echo ""
                
            } >> "$REPORT_DIR/redis_performance.md"
        done
    else
        echo "❌ No Redis pods found in namespace $ARGOCD_NAMESPACE" >> "$REPORT_DIR/redis_performance.md"
    fi
}

# Generate performance alerts
generate_alerts() {
    log_info "Generating performance alerts..."
    
    {
        echo "# Performance Alerts and Recommendations"
        echo "Generated: $(date)"
        echo ""
        echo "## Automated Analysis"
        echo ""
    } > "$REPORT_DIR/alerts.md"
    
    local alert_count=0
    
    # Check for high resource usage
    if [ -f "$REPORT_DIR/resource_data.csv" ]; then
        local high_cpu_pods=$(tail -n +2 "$REPORT_DIR/resource_data.csv" | \
            awk -F',' '$3 > 1000 {print $2}' | sort -u | wc -l)
        
        local high_memory_pods=$(tail -n +2 "$REPORT_DIR/resource_data.csv" | \
            awk -F',' '$4 > 1000 {print $2}' | sort -u | wc -l)
        
        if [ "$high_cpu_pods" -gt 0 ]; then
            {
                echo "🚨 **HIGH CPU USAGE ALERT**"
                echo "- $high_cpu_pods pods showing high CPU usage (>1000m)"
                echo "- Consider reviewing resource limits and requests"
                echo ""
            } >> "$REPORT_DIR/alerts.md"
            ((alert_count++))
        fi
        
        if [ "$high_memory_pods" -gt 0 ]; then
            {
                echo "🚨 **HIGH MEMORY USAGE ALERT**" 
                echo "- $high_memory_pods pods showing high memory usage (>1000MB)"
                echo "- Review memory limits and potential memory leaks"
                echo ""
            } >> "$REPORT_DIR/alerts.md"
            ((alert_count++))
        fi
    fi
    
    # Check sync status alerts
    local total_apps=$(kubectl get applications -A --no-headers 2>/dev/null | wc -l)
    local out_of_sync=$(kubectl get applications -A -o json 2>/dev/null | jq -r '.items[] | select(.status.sync.status == "OutOfSync") | .metadata.name' | wc -l)
    
    if [ "$total_apps" -gt 0 ] && [ $((out_of_sync * 100 / total_apps)) -gt 20 ]; then
        {
            echo "⚠️ **SYNC STATUS ALERT**"
            echo "- $out_of_sync out of $total_apps applications are OutOfSync ($((out_of_sync * 100 / total_apps))%)"
            echo "- Consider investigating sync issues"
            echo ""
        } >> "$REPORT_DIR/alerts.md"
        ((alert_count++))
    fi
    
    # Summary
    {
        echo "## Alert Summary"
        echo ""
        if [ $alert_count -eq 0 ]; then
            echo "✅ **No critical alerts detected**"
            echo ""
            echo "Your ArgoCD installation appears to be performing well."
        else
            echo "📊 **$alert_count alerts detected**"
            echo ""
            echo "Review the alerts above and take appropriate action."
        fi
        
        echo ""
        echo "## General Recommendations"
        echo ""
        echo "- Monitor resource usage regularly"
        echo "- Set up proper resource limits and requests"
        echo "- Keep applications in sync"
        echo "- Maintain Redis HA for production"
        echo "- Regular performance audits"
        
    } >> "$REPORT_DIR/alerts.md"
    
    log_success "Generated $alert_count performance alerts"
}

# Generate comprehensive report
generate_comprehensive_report() {
    log_info "Generating comprehensive performance report..."
    
    {
        echo "# ArgoCD Performance Analysis Report"
        echo "Generated: $(date)"
        echo "Monitoring Duration: ${MONITOR_DURATION} seconds"
        echo ""
        echo "## Executive Summary"
        echo ""
        
        # System overview
        local total_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l)
        local running_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_apps=$(kubectl get applications -A --no-headers 2>/dev/null | wc -l)
        
        echo "### System Overview"
        echo "- **ArgoCD Pods**: $running_pods/$total_pods running"
        echo "- **Total Applications**: $total_apps"
        echo "- **Monitoring Period**: $(date -d @$(($(date +%s) - MONITOR_DURATION)) '+%H:%M:%S') - $(date '+%H:%M:%S')"
        echo ""
        
        echo "### Performance Status"
        local status="🟢 Good"
        if [ -f "$REPORT_DIR/alerts.md" ] && grep -q "🚨" "$REPORT_DIR/alerts.md"; then
            status="🔴 Issues Detected"
        elif [ -f "$REPORT_DIR/alerts.md" ] && grep -q "⚠️" "$REPORT_DIR/alerts.md"; then
            status="🟡 Warnings"
        fi
        echo "- **Overall Status**: $status"
        echo ""
        
        echo "## Report Files"
        echo ""
        echo "1. \`components_performance.md\` - Component status and resources"
        echo "2. \`api_performance.md\` - API response times and health"
        echo "3. \`resource_utilization.md\` - CPU/Memory usage over time"
        echo "4. \`sync_performance.md\` - Application sync status and health"
        echo "5. \`redis_performance.md\` - Redis cluster performance"
        echo "6. \`alerts.md\` - Performance alerts and recommendations"
        echo "7. \`resource_data.csv\` - Raw resource usage data"
        echo ""
        
        echo "## Quick Actions"
        echo ""
        echo "### If Performance Issues Detected:"
        echo "1. Review alerts in \`alerts.md\`"
        echo "2. Check resource utilization trends"
        echo "3. Investigate high-usage components"
        echo "4. Consider scaling or resource adjustments"
        echo ""
        
        echo "### For Optimization:"
        echo "1. Set appropriate resource limits"
        echo "2. Monitor sync performance regularly"
        echo "3. Maintain Redis HA configuration"
        echo "4. Schedule regular performance audits"
        
    } > "$REPORT_DIR/README.md"
}

# Main execution
main() {
    print_header
    
    check_prerequisites
    monitor_components &
    monitor_api_performance &
    monitor_sync_performance &
    monitor_redis_performance &
    
    # Wait for background jobs to complete
    wait
    
    # Run resource monitoring (sequential - requires time)
    monitor_resource_utilization
    
    generate_alerts
    generate_comprehensive_report
    
    echo
    log_success "Performance monitoring completed successfully!"
    log_info "Report available in: $REPORT_DIR/"
    echo
    echo -e "${CYAN}To view the comprehensive report:${NC}"
    echo "  cat $REPORT_DIR/README.md"
    echo ""
    echo -e "${CYAN}To analyze resource trends:${NC}"
    echo "  cat $REPORT_DIR/resource_utilization.md"
    echo ""
    echo -e "${CYAN}To view alerts:${NC}"
    echo "  cat $REPORT_DIR/alerts.md"
}

# Show usage
show_usage() {
    echo "ArgoCD Performance Monitor"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --duration SECONDS    Monitor duration (default: 300)"
    echo "  -i, --interval SECONDS    Sample interval (default: 10)"
    echo "  -n, --namespace NAME      ArgoCD namespace (default: argocd)"
    echo "  -h, --help               Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  ARGOCD_NAMESPACE         ArgoCD namespace"
    echo "  MONITOR_DURATION         Monitoring duration in seconds"
    echo "  SAMPLE_INTERVAL          Sampling interval in seconds"
    echo ""
    echo "Examples:"
    echo "  $0                              # Default 5-minute monitoring"
    echo "  $0 -d 600 -i 5                 # 10-minute monitoring, 5s interval"
    echo "  $0 --namespace argocd-prod      # Custom namespace"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            MONITOR_DURATION="$2"
            shift 2
            ;;
        -i|--interval)
            SAMPLE_INTERVAL="$2"
            shift 2
            ;;
        -n|--namespace)
            ARGOCD_NAMESPACE="$2"
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