# Monitoreo de Performance

Herramientas especializadas para monitorear y analizar el rendimiento de ArgoCD.

## 📊 Performance Monitor

### Descripción
Monitor en tiempo real del rendimiento de ArgoCD con análisis completo de componentes y métricas.

### Ubicación
`Performance_monitor/performance_monitor.sh`

### Características Avanzadas
- **Monitoreo Configurable**: Duración e intervalos personalizables
- **Métricas en Tiempo Real**: CPU/Memoria de todos los componentes
- **Análisis de APIs**: Tiempos de respuesta de endpoints
- **Estado de Sincronización**: Monitoreo de aplicaciones
- **Alertas Automáticas**: Por alto uso de recursos
- **Exportación CSV**: Datos para análisis posterior
- **Integración Prometheus**: Métricas compatibles

### Uso
```bash
# Monitoreo estándar (5 minutos)
./Performance_monitor/performance_monitor.sh

# Monitoreo extendido (30 minutos)
./Performance_monitor/performance_monitor.sh --duration 30

# Intervalos personalizados (cada 10 segundos)
./Performance_monitor/performance_monitor.sh --interval 10

# Solo componentes específicos
./Performance_monitor/performance_monitor.sh --components "server,controller"

# Exportar a CSV
./Performance_monitor/performance_monitor.sh --export-csv --output /tmp/metrics.csv
```

### Métricas Monitoreadas

#### 🖥️ Recursos de Sistema
```bash
📊 System Resources:
- ArgoCD Server: CPU 45% | Memory 1.2GB/2GB (60%)
- Controller: CPU 23% | Memory 800MB/1.5GB (53%)
- Repo Server: CPU 12% | Memory 512MB/1GB (51%)
- Redis HA: CPU 8% | Memory 256MB/512MB (50%)
- Dex: CPU 3% | Memory 128MB/256MB (50%)
```

#### 🌐 Performance de APIs
```bash
🌐 API Performance:
- /api/v1/applications: 145ms avg (✅ Good)
- /api/v1/clusters: 89ms avg (✅ Good)
- /api/v1/repositories: 234ms avg (⚠️ Slow)
- /api/v1/projects: 67ms avg (✅ Good)
- Healthz endpoint: 12ms avg (✅ Excellent)
```

#### 🔄 Sincronización de Aplicaciones
```bash
🔄 Application Sync Status:
- Total Applications: 47
- Synced: 45 (95.7%) ✅
- Out of Sync: 2 (4.3%) ⚠️
- Sync Failures: 0 (0%) ✅
- Average Sync Time: 12.3s
```

#### 💾 Redis Performance
```bash
💾 Redis HA Performance:
- Connections: 23/100 (23%)
- Memory Usage: 45MB/128MB (35%)
- Commands/sec: 145
- Hit Rate: 94.5%
- Replication Lag: 0ms
```

### Reportes Automatizados

#### Reporte de Performance Completo
```bash
# Generar reporte completo
./performance_monitor.sh --full-report --duration 60

ArgoCD Performance Report - 2025-08-22 14:30:25
===============================================

📈 Executive Summary:
- Overall Health Score: 87/100 (Good)
- Critical Issues: 0
- Warnings: 2
- Recommendations: 3

📊 Resource Utilization (60min avg):
- CPU: 34% (Target: <70%) ✅
- Memory: 58% (Target: <80%) ✅
- Storage: 12GB/50GB (24%) ✅
- Network: 15MB/s (Normal) ✅

🚨 Performance Issues:
⚠️ Repository scan taking >3 minutes (Target: <2min)
⚠️ Application sync queue backlog detected

💡 Recommendations:
1. Scale repo-server to 3 replicas
2. Increase repository scan timeout
3. Enable application parallelism
```

#### Trending Analysis
```bash
📈 Performance Trends (Last 7 days):
- CPU Usage: ↗️ +12% increase
- Memory Usage: ↘️ -5% decrease  
- API Response Time: ↗️ +8% increase
- Sync Success Rate: → Stable 95%
- Active Applications: ↗️ +3 new apps
```

## 🎯 Métricas Especializadas

### Application Performance
```bash
🎯 Application Performance Analysis:
Top 5 Slowest Sync Applications:
1. frontend-prod: 45.2s (⚠️ Needs optimization)
2. backend-api: 23.1s (✅ Acceptable)
3. database-cluster: 18.7s (✅ Good)
4. monitoring-stack: 15.2s (✅ Good)
5. logging-system: 12.8s (✅ Good)

Sync Failure Analysis:
- Network timeouts: 15% of failures
- Resource conflicts: 35% of failures
- Validation errors: 50% of failures
```

### Controller Performance
```bash
🎮 Controller Performance:
- Work Queue Length: 23 items
- Processing Rate: 145 items/min
- Error Rate: 0.2% (Target: <1%) ✅
- Reconciliation Time: 8.5s avg
- Active Workers: 10/10 ✅

Recent Activity:
- Applications reconciled: 234 (last hour)
- Projects reconciled: 12 (last hour)
- Repositories scanned: 8 (last hour)
```

### Repository Performance
```bash
📚 Repository Performance:
Active Repositories: 8
┌─────────────────────────────────────┬──────────┬─────────┬────────┐
│ Repository                          │ Size     │ Scan    │ Status │
├─────────────────────────────────────┼──────────┼─────────┼────────┤
│ github.com/company/k8s-manifests    │ 45MB     │ 2.1min  │ ✅ OK  │
│ github.com/company/helm-charts      │ 23MB     │ 1.5min  │ ✅ OK  │
│ github.com/company/app-configs      │ 12MB     │ 45s     │ ✅ OK  │
│ github.com/company/infrastructure   │ 67MB     │ 3.2min  │ ⚠️ Slow│
└─────────────────────────────────────┴──────────┴─────────┴────────┘
```

## 📋 Alertas y Thresholds

### Configuración de Alertas
```bash
# Configurar thresholds personalizados
cat > performance_thresholds.yaml <<EOF
thresholds:
  cpu:
    warning: 70
    critical: 85
  memory:
    warning: 80  
    critical: 90
  api_response:
    warning: 1000  # ms
    critical: 2000 # ms
  sync_time:
    warning: 300   # seconds
    critical: 600  # seconds
  
notifications:
  slack_webhook: "https://hooks.slack.com/..."
  email: "devops@company.com"
  pagerduty_key: "your-integration-key"
EOF
```

### Alertas Activas
```bash
🚨 Active Performance Alerts:

⚠️  WARNING: Repository Scan Slow
- Repository: github.com/company/infrastructure  
- Current: 3.2min | Threshold: 2min
- Impact: Delayed application updates
- Action: Consider repository optimization

⚠️  WARNING: High Memory Usage
- Component: argocd-controller
- Current: 1.8GB | Limit: 2GB (90%)
- Trend: Increasing last 2 hours
- Action: Consider scaling up
```

## 🔧 Optimización de Performance

### Recomendaciones Automáticas
```bash
💡 Performance Optimization Recommendations:

🚀 High Impact:
1. Scale repo-server to 3 replicas
   - Current: 1 replica handling 8 repositories
   - Expected improvement: -40% scan time

2. Enable application parallelism
   - Current: Serial processing
   - Expected improvement: -60% sync time

3. Increase controller workers
   - Current: 10 workers
   - Recommended: 15 workers
   - Expected improvement: -25% queue time

🎯 Medium Impact:
1. Configure repository caching
2. Optimize large repository structure
3. Enable compressed git communication
```

### Auto-Scaling Suggestions
```bash
📈 Auto-Scaling Analysis:

Current Configuration:
- Server replicas: 2 (CPU: 45%)
- Repo-server replicas: 1 (CPU: 78%) ⚠️
- Redis replicas: 3 (CPU: 8%)

Scaling Recommendations:
- repo-server: Scale to 2 replicas immediately
- server: Current scaling adequate
- Consider HPA for repo-server component
```

## 📊 Métricas Históricas

### Exportación para Analytics
```bash
# Exportar datos históricos
./performance_monitor.sh --export-historical --days 30 --format csv

# Métricas para Grafana
./performance_monitor.sh --prometheus-format > argocd_metrics.prom

# Datos para análisis de tendencias
./performance_monitor.sh --trend-analysis --weeks 4
```

### Integration con Observability Stack
```bash
# Prometheus metrics endpoint
curl http://argocd-server:8080/metrics

# Custom metrics para monitoring
./performance_monitor.sh --custom-metrics \
  --metric "app_sync_duration_seconds" \
  --metric "repo_scan_duration_seconds" \
  --metric "api_request_duration_seconds"
```

## 🚀 Performance Tuning

### Configuración Optimizada
```yaml
# argocd-server optimizations
server:
  config:
    application.instanceLabelKey: argocd.argoproj.io/instance
    application.resourceTrackingMethod: annotation
  extraArgs:
    - --repo-server-timeout-seconds=300
    - --controller-parallelism-limit=50

# argocd-repo-server optimizations  
repoServer:
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  extraArgs:
    - --parallelismlimit=20
    - --repo-cache-expiration=24h

# controller optimizations
controller:
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
  env:
    - name: ARGOCD_CONTROLLER_REPLICAS
      value: "1"
    - name: ARGOCD_CONTROLLER_PARALLELISM_LIMIT
      value: "50"
```

### Redis Optimization
```yaml
redis-ha:
  enabled: true
  replicas: 3
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 200m
  redis:
    config:
      maxmemory: "400mb"
      maxmemory-policy: "allkeys-lru"
      save: "900 1 300 10"
```

## 📞 Troubleshooting Performance

### Performance Issues Comunes

#### Alto Uso de CPU
```bash
# Identificar procesos con alto CPU
kubectl top pods -n argocd --sort-by=cpu

# Analizar logs para patrones
./performance_monitor.sh --analyze-logs --component controller

# Verificar configuración de resources
kubectl describe deployment argocd-controller -n argocd
```

#### Lentitud en Sincronización
```bash
# Analizar cuellos de botella
./performance_monitor.sh --sync-analysis --detailed

# Verificar repository performance
./performance_monitor.sh --repo-analysis

# Revisar network latency
./performance_monitor.sh --network-test
```

#### Problemas de Memoria
```bash
# Memory leak detection
./performance_monitor.sh --memory-analysis --duration 60

# Garbage collection analysis
./performance_monitor.sh --gc-analysis

# Resource cleanup recommendations
./performance_monitor.sh --cleanup-suggestions
```