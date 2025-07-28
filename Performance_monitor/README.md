# 📊 ArgoCD Performance Monitor

Herramienta avanzada de monitoreo en tiempo real para analizar el rendimiento de componentes ArgoCD, APIs, recursos del sistema y aplicaciones.

## 🎯 Características Principales

### 🔍 **Monitoreo Integral**
- ✅ Componentes ArgoCD (Server, Controller, Repo Server, Redis)
- ✅ Rendimiento de APIs con tiempos de respuesta
- ✅ Utilización de recursos (CPU/Memoria) en tiempo real
- ✅ Rendimiento de sincronización de aplicaciones
- ✅ Métricas de Redis HA/standalone
- ✅ Alertas automatizadas y recomendaciones

### 📈 **Análisis de Tendencias**
- 📊 Monitoreo continuo con intervalos configurables
- 📋 Datos históricos en formato CSV para análisis
- 🎯 Identificación de picos de uso y patrones
- 📉 Estadísticas agregadas y promedios

### 🚨 **Sistema de Alertas**
- ⚠️ Detección automática de alto uso de recursos
- 🔍 Análisis de estado de sincronización
- 📊 Recomendaciones basadas en métricas
- 🎯 Alertas clasificadas por severidad

## 🚀 Uso

### Ejecución Básica
```bash
# Monitoreo estándar (5 minutos)
./performance_monitor.sh

# Monitoreo extendido (10 minutos, muestras cada 5 segundos)
./performance_monitor.sh -d 600 -i 5

# Namespace personalizado
./performance_monitor.sh -n argocd-production
```

### Opciones Avanzadas
```bash
# Monitoreo personalizado completo
ARGOCD_NAMESPACE=argocd-prod \
MONITOR_DURATION=900 \
SAMPLE_INTERVAL=15 \
./performance_monitor.sh

# Solo componentes críticos (modo rápido)
./performance_monitor.sh -d 60 -i 5
```

### Parámetros de Configuración
```bash
# Opciones de línea de comandos
-d, --duration SECONDS      # Duración del monitoreo (default: 300s)
-i, --interval SECONDS      # Intervalo de muestreo (default: 10s)
-n, --namespace NAME        # Namespace de ArgoCD (default: argocd)
-h, --help                  # Mostrar ayuda

# Variables de entorno
export ARGOCD_NAMESPACE=argocd-prod    # Namespace personalizado
export MONITOR_DURATION=600           # 10 minutos de monitoreo
export SAMPLE_INTERVAL=5              # Muestras cada 5 segundos
```

## 📋 Reportes Generados

### Estructura de Reportes
```
performance_report_YYYYMMDD_HHMMSS/
├── README.md                     # Resumen ejecutivo
├── components_performance.md     # Estado de componentes ArgoCD
├── api_performance.md           # Rendimiento de APIs
├── resource_utilization.md      # Utilización de recursos
├── sync_performance.md          # Rendimiento de sincronización
├── redis_performance.md         # Métricas de Redis
├── alerts.md                    # Alertas y recomendaciones
└── resource_data.csv            # Datos brutos para análisis
```

### Ejemplo de Resumen Ejecutivo
```markdown
## Executive Summary

### System Overview
- **ArgoCD Pods**: 8/8 running
- **Total Applications**: 47
- **Monitoring Period**: 14:30:00 - 14:35:00

### Performance Status
- **Overall Status**: 🟢 Good

## Quick Actions
### If Performance Issues Detected:
1. Review alerts in `alerts.md`
2. Check resource utilization trends
3. Investigate high-usage components
4. Consider scaling or resource adjustments
```

### Ejemplo de Alertas
```markdown
🚨 **HIGH CPU USAGE ALERT**
- 2 pods showing high CPU usage (>1000m)
- Consider reviewing resource limits and requests

⚠️ **SYNC STATUS ALERT**
- 8 out of 47 applications are OutOfSync (17%)
- Consider investigating sync issues
```

### Ejemplo de Métricas de Componentes
```markdown
### argocd-server

**Pod Status:**
NAME                            READY   STATUS    RESTARTS   AGE
argocd-server-7f4d8b8c9-x5zv2  1/1     Running   0          2d

**Resource Usage:**
NAME                            CPU(cores)   MEMORY(bytes)
argocd-server-7f4d8b8c9-x5zv2  45m          128Mi
```

## 📊 Análisis de Datos

### Datos CSV para Análisis Avanzado
```csv
timestamp,pod_name,cpu_cores,memory_mb
2024-01-15 14:30:10,argocd-server-7f4d8b8c9-x5zv2,45,128
2024-01-15 14:30:20,argocd-server-7f4d8b8c9-x5zv2,52,132
2024-01-15 14:30:30,argocd-application-controller-0,180,256
```

### Análisis con Herramientas Externas
```bash
# Análisis con awk
awk -F',' 'NR>1 {cpu[$2]+=$3; mem[$2]+=$4; count[$2]++} 
END {for(pod in cpu) printf "%s: CPU=%.1f, MEM=%.1f\n", pod, cpu[pod]/count[pod], mem[pod]/count[pod]}' \
resource_data.csv

# Importar a Excel/Google Sheets para gráficos
# Usar Python pandas para análisis estadístico
python3 -c "
import pandas as pd
df = pd.read_csv('resource_data.csv')
print(df.groupby('pod_name')[['cpu_cores', 'memory_mb']].agg(['mean', 'max', 'std']))
"
```

## 🎯 Casos de Uso Comunes

### **1. Diagnóstico de Rendimiento**
```bash
# Cuando ArgoCD está lento
./performance_monitor.sh -d 300 -i 5

# Revisar alertas generadas
cat performance_report_*/alerts.md

# Analizar componente específico
grep "argocd-server" performance_report_*/components_performance.md
```

### **2. Planificación de Capacidad**
```bash
# Monitoreo extendido para planificación
./performance_monitor.sh -d 1800 -i 30  # 30 minutos

# Análisis de tendencias
cat performance_report_*/resource_utilization.md

# Identificar patrones de uso
awk -F',' 'NR>1 {print $1, $3}' performance_report_*/resource_data.csv | \
  gnuplot -e "set terminal png; plot '-' using 2 with lines"
```

### **3. Monitoreo de Producción**
```bash
# Script de monitoreo continuo
#!/bin/bash
while true; do
    ./performance_monitor.sh -d 300 -i 10
    
    # Enviar alertas si hay problemas
    if grep -q "🚨" performance_report_*/alerts.md; then
        # Enviar notificación
        curl -X POST $SLACK_WEBHOOK -d @performance_report_*/alerts.md
    fi
    
    # Esperar 1 hora
    sleep 3600
done
```

### **4. Optimización Post-Despliegue**
```bash
# Después de actualizar ArgoCD
./performance_monitor.sh -d 600 -i 5

# Comparar con baseline anterior
diff baseline_performance/resource_utilization.md \
     performance_report_*/resource_utilization.md
```

## 🔧 Métricas Monitoreadas

### **Componentes ArgoCD**
```bash
# Server
- Estado de pods
- Uso de CPU/Memoria
- Tiempo de respuesta API
- Conectividad

# Application Controller
- Rendimiento de sincronización
- Carga de trabajo
- Memoria utilizada
- Errores en logs

# Repo Server
- Operaciones Git
- Cache hits/misses
- Tiempo de clonado
- Uso de recursos

# Redis
- Conexiones activas
- Uso de memoria
- Operaciones por segundo
- Fragmentación
```

### **APIs y Conectividad**
```bash
# Endpoints monitoreados
/api/version              # Info de versión
/api/v1/applications     # Lista de aplicaciones
/api/v1/projects         # Proyectos
/api/v1/repositories     # Repositorios
/api/v1/clusters         # Clusters

# Métricas de API
- Tiempo de respuesta (ms)
- Código de estado HTTP
- Disponibilidad
- Errores de autenticación
```

### **Sincronización y Salud**
```bash
# Estados de Sync
- Synced: Aplicaciones sincronizadas
- OutOfSync: Requieren sincronización
- Unknown: Estado desconocido

# Estados de Health
- Healthy: Aplicaciones saludables
- Degraded: Con problemas
- Progressing: En progreso
```

## 🚨 Interpretación de Alertas

### **Niveles de Severidad**
- 🚨 **Crítico**: Acción inmediata requerida
- ⚠️ **Advertencia**: Atención necesaria
- ℹ️ **Información**: Para conocimiento

### **Umbrales de Alerta**
```bash
# CPU
- Normal: < 500m por pod
- Alto: 500m - 1000m
- Crítico: > 1000m

# Memoria
- Normal: < 500MB por pod
- Alto: 500MB - 1GB
- Crítico: > 1GB

# Sincronización
- Bueno: < 10% OutOfSync
- Moderado: 10-20% OutOfSync
- Crítico: > 20% OutOfSync
```

## 📈 Integración y Automatización

### **CI/CD Integration**
```yaml
# .github/workflows/argocd-performance.yml
name: ArgoCD Performance Monitor
on:
  schedule:
    - cron: '0 */6 * * *'  # Cada 6 horas

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Monitor Performance
        run: ./Performance_monitor/performance_monitor.sh -d 180
      - name: Upload Reports
        uses: actions/upload-artifact@v3
        with:
          name: performance-reports
          path: performance_report_*
```

### **Prometheus Integration**
```bash
# Exportar métricas a Prometheus
#!/bin/bash
REPORT_DIR=$(ls -td performance_report_* | head -1)

# CPU metrics
awk -F',' 'NR>1 {print "argocd_cpu_usage{pod=\"" $2 "\"} " $3/1000}' \
  $REPORT_DIR/resource_data.csv > /var/lib/node_exporter/textfile_collector/argocd_cpu.prom

# Memory metrics  
awk -F',' 'NR>1 {print "argocd_memory_usage{pod=\"" $2 "\"} " $4*1024*1024}' \
  $REPORT_DIR/resource_data.csv > /var/lib/node_exporter/textfile_collector/argocd_memory.prom
```

### **Dashboard Grafana**
```json
{
  "dashboard": {
    "title": "ArgoCD Performance",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "argocd_cpu_usage"
          }
        ]
      },
      {
        "title": "Memory Usage", 
        "type": "graph",
        "targets": [
          {
            "expr": "argocd_memory_usage"
          }
        ]
      }
    ]
  }
}
```

## 🛠️ Troubleshooting

### **Error: "metrics-server not available"**
```bash
# Instalar metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verificar instalación
kubectl get pods -n kube-system | grep metrics-server
```

### **Error: "Port forward failed"**
```bash
# Verificar servicio ArgoCD
kubectl get svc -n argocd argocd-server

# Usar puerto alternativo
kubectl port-forward -n argocd svc/argocd-server 8081:80
```

### **Datos CSV vacíos**
```bash
# Verificar permisos de metrics
kubectl auth can-i get pods --subresource=metrics

# Verificar metrics-server
kubectl top nodes
```

---

**🎯 Objetivo**: Proporcionar visibilidad completa del rendimiento de ArgoCD para optimización proactiva y resolución rápida de problemas.