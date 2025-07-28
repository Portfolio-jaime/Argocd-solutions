# 🕵️ ArgoCD Orphan Resources Analyzer

Herramienta avanzada para identificar y analizar recursos huérfanos en clusters de Kubernetes gestionados por ArgoCD. Detecta recursos que existen en el cluster pero no están siendo gestionados por ninguna aplicación de ArgoCD.

## 🎯 ¿Qué hace?

### 🔍 **Análisis Completo**
- ✅ Escanea todos los recursos del cluster
- ✅ Identifica recursos gestionados por ArgoCD
- ✅ Detecta recursos huérfanos (no gestionados)
- ✅ Analiza dependencias y seguridad de limpieza
- ✅ Genera scripts de limpieza automatizados

### 📊 **Reportes Detallados**
- 📋 Resumen ejecutivo con métricas
- 🗂️ Lista detallada de recursos huérfanos
- ⚡ Análisis de candidatos para limpieza
- 🛡️ Evaluación de seguridad por recurso
- 📈 Estadísticas y recomendaciones

### 🧹 **Limpieza Segura**
- 🟢 Script de limpieza segura (recursos sin riesgo)
- 🟡 Script de limpieza completa (requiere revisión)
- 🔍 Análisis de dependencias entre recursos
- ⚠️ Advertencias sobre recursos críticos

## 📦 Funcionalidades

### **Detección de Huérfanos**
```bash
# Detecta recursos en estas categorías:
- Pods sin controlador padre
- Services sin endpoints
- ConfigMaps/Secrets no referenciados
- Jobs completados antiguos
- ReplicaSets sin Deployment
- PVCs no utilizados
- Resources sin anotaciones ArgoCD
```

### **Análisis de Seguridad**
```bash
# Clasifica recursos por nivel de riesgo:
- SAFE: Bajo riesgo, probablemente seguro eliminar
- MODERATE: Riesgo medio, revisar antes de eliminar  
- RISKY: Alto riesgo, análisis cuidadoso necesario
```

### **Tipos de Recursos Analizados**
- **Workloads**: Pods, Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs
- **Servicios**: Services, Ingresses, NetworkPolicies
- **Configuración**: ConfigMaps, Secrets
- **Almacenamiento**: PersistentVolumeClaims
- **RBAC**: ServiceAccounts, Roles, RoleBindings, ClusterRoles, ClusterRoleBindings
- **Scaling**: HorizontalPodAutoscalers
- **ArgoCD**: Applications, ApplicationSets, AppProjects

## 🚀 Uso

### Ejecución Básica
```bash
# Ejecutar análisis completo
./orphan_analyzer.sh

# Con namespace personalizado de ArgoCD
ARGOCD_NAMESPACE=argocd-prod ./orphan_analyzer.sh

# Modo dry-run (sin generar scripts de limpieza)
DRY_RUN=true ./orphan_analyzer.sh
```

### Parámetros de Configuración
```bash
# Variables de entorno disponibles
export ARGOCD_NAMESPACE=argocd        # Namespace de ArgoCD (default: argocd)
export DRY_RUN=false                  # Solo análisis, no genera limpieza (default: true)
```

## 📋 Salida y Reportes

### Estructura de Reportes
```
orphan_analysis_YYYYMMDD_HHMMSS/
├── README.md                         # Resumen ejecutivo
├── orphaned_resources.md             # Lista detallada de huérfanos
├── cleanup_candidates.md             # Análisis de seguridad de limpieza
├── managed_resources_summary.md      # Recursos gestionados por ArgoCD
├── cleanup_safe.sh                   # Script de limpieza segura
└── cleanup_all.sh                    # Script de limpieza completa
```

### Ejemplo de Resumen Ejecutivo
```markdown
## Executive Summary

- **Total Resources Scanned**: 1,247
- **ArgoCD Managed Resources**: 892
- **Orphaned Resources Found**: 23
- **Orphan Percentage**: 2%

✅ **Good!** Only a few orphaned resources found.

This is normal for active clusters. Review the cleanup recommendations below.
```

### Ejemplo de Análisis de Huérfanos
```markdown
## Orphaned Resources by Type

- **ConfigMap**: 8 resources
- **Secret**: 5 resources  
- **Service**: 4 resources
- **Job**: 3 resources
- **ReplicaSet**: 3 resources

| Namespace | Kind | Name | Potential Issues |
|-----------|------|------|------------------|
| default | ReplicaSet | old-app-xyz | Missing parent Deployment |
| staging | Service | unused-svc | No endpoints found |
| prod | ConfigMap | temp-config | Not referenced by any Pod |
```

### Ejemplo de Candidatos de Limpieza
```markdown
| Resource | Namespace | Safety Level | Reason |
|----------|-----------|--------------|--------|
| ConfigMap/temp-data | staging | SAFE | No active references found |
| Service/old-api | default | RISKY | Has 2 active endpoints |
| Job/cleanup-job | prod | SAFE | Job completed successfully |
| Secret/temp-secret | dev | SAFE | No active references found |
```

## 🛡️ Seguridad y Mejores Prácticas

### **Antes de Ejecutar**
```bash
# 1. Verificar permisos
kubectl auth can-i list pods --all-namespaces
kubectl auth can-i get applications --all-namespaces

# 2. Hacer backup del cluster (opcional pero recomendado)
kubectl get all -A -o yaml > cluster_backup.yaml

# 3. Ejecutar en modo dry-run primero
DRY_RUN=true ./orphan_analyzer.sh
```

### **Revisión de Scripts de Limpieza**
```bash
# SIEMPRE revisar antes de ejecutar
cat orphan_analysis_*/cleanup_safe.sh

# Ejecutar limpieza segura
./orphan_analysis_*/cleanup_safe.sh

# Para limpieza completa, descomenta líneas manualmente
vim orphan_analysis_*/cleanup_all.sh
```

### **Exclusiones Automáticas**
El analyzer excluye automáticamente:
- Recursos en namespaces del sistema (`kube-system`, `kube-public`, `kube-node-lease`)
- Recursos en el namespace de ArgoCD
- Recursos con anotaciones de ArgoCD válidas
- Recursos críticos del sistema

## 🔧 Casos de Uso Comunes

### **1. Limpieza Periódica**
```bash
# Ejecutar semanalmente para mantener cluster limpio
0 2 * * 1 /path/to/orphan_analyzer.sh
```

### **2. Pre-actualización de ArgoCD**
```bash
# Limpiar huérfanos antes de actualizar ArgoCD
./orphan_analyzer.sh
./orphan_analysis_*/cleanup_safe.sh
# Proceder con actualización de ArgoCD
```

### **3. Auditoría de Recursos**
```bash
# Generar reporte para auditoría
DRY_RUN=true ./orphan_analyzer.sh
# Enviar orphan_analysis_*/README.md al equipo
```

### **4. Troubleshooting de Aplicaciones**
```bash
# Verificar si hay recursos huérfanos de una app específica
./orphan_analyzer.sh
grep "my-app" orphan_analysis_*/orphaned_resources.md
```

## 📊 Métricas y Monitoreo

### **Interpretar Métricas**
- **0-5% huérfanos**: Excelente gestión de recursos
- **5-15% huérfanos**: Normal, limpieza periódica recomendada
- **15%+ huérfanos**: Requiere atención, revisar prácticas

### **Integración con Monitoreo**
```bash
# Extraer métricas para Prometheus/Grafana
ORPHAN_COUNT=$(wc -l < orphan_analysis_*/orphaned_resources.md)
echo "argocd_orphan_resources $ORPHAN_COUNT" > /var/lib/node_exporter/textfile_collector/argocd_orphans.prom
```

## 🚨 Troubleshooting

### **Error: "ArgoCD namespace not found"**
```bash
# Verificar namespace correcto
kubectl get namespaces | grep argo

# Usar namespace correcto
ARGOCD_NAMESPACE=argocd-production ./orphan_analyzer.sh
```

### **Error: "Permission denied"**
```bash
# Verificar permisos
kubectl auth can-i get applications --all-namespaces
kubectl auth can-i list pods --all-namespaces

# Usar contexto con permisos adecuados
kubectl config use-context admin-context
```

### **Muchos Falsos Positivos**
```bash
# Verificar que las aplicaciones tengan las anotaciones correctas
kubectl get applications -A -o yaml | grep -A 5 annotations

# Verificar que ArgoCD esté funcionando correctamente
kubectl get pods -n argocd
```

## 🔄 Automatización

### **Script de Limpieza Automática**
```bash
#!/bin/bash
# auto_cleanup.sh

# Ejecutar análisis
./orphan_analyzer.sh

# Ejecutar limpieza segura automáticamente
LATEST_REPORT=$(ls -td orphan_analysis_* | head -1)
$LATEST_REPORT/cleanup_safe.sh

# Enviar reporte por email/Slack
curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"ArgoCD Orphan Cleanup Completed: $(cat $LATEST_REPORT/README.md | grep 'Orphaned Resources Found')\"}" \
  $SLACK_WEBHOOK_URL
```

### **Integración CI/CD**
```yaml
# .github/workflows/orphan-cleanup.yml
name: ArgoCD Orphan Cleanup
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2 AM

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
      - name: Run Orphan Analysis
        run: ./Orphan_resources_analyzer/orphan_analyzer.sh
      - name: Upload Report
        uses: actions/upload-artifact@v3
        with:
          name: orphan-analysis-report
          path: orphan_analysis_*
```

## 🤝 Contribuir

### **Agregar Nuevos Tipos de Recursos**
1. Añadir el tipo a `resource_types` array
2. Implementar lógica de detección específica
3. Añadir análisis de seguridad apropiado
4. Actualizar documentación

### **Mejorar Detección**
- Implementar mejor análisis de dependencias
- Añadir más patrones de recursos huérfanos
- Mejorar clasificación de seguridad
- Optimizar rendimiento para clusters grandes

---

**🎯 Objetivo**: Mantener clusters de Kubernetes limpios y eficientes mediante la identificación y limpieza segura de recursos huérfanos no gestionados por ArgoCD.