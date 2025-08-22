# Herramientas de Validación y Diagnóstico

Esta sección cubre las herramientas disponibles para validación y diagnóstico del estado de ArgoCD.

## 📋 CRDs Checker

### Descripción
Herramienta para verificar la compatibilidad de Custom Resource Definitions (CRDs) antes de actualizar ArgoCD.

### Ubicación
`Check_CRDs-K8s/check_crds-argocd.sh`

### Uso
```bash
# Verificación completa de CRDs
./Check_CRDs-K8s/check_crds-argocd.sh

# Análisis específico por versión
./Check_CRDs-K8s/check_crds-argocd.sh --target-version v2.11.3

# Modo verbose para detalles
./Check_CRDs-K8s/check_crds-argocd.sh --verbose
```

### Funcionalidades
- **Detección Automática**: Identifica instalaciones de Argo CD (Helm y manual)
- **Análisis de Compatibilidad**: Compara versiones actuales vs objetivo
- **Verificación de API**: Valida versiones de API (v1alpha1, v1beta1)
- **Sincronización**: Verifica estado entre ArgoCD y Argo Rollouts
- **Información de Cluster**: Análisis específico para EKS y otros providers

### Resultados del Análisis
```bash
ArgoCD Installation Status:
✅ ArgoCD detected (Helm installation)
✅ Version: v2.10.9
✅ Namespace: argocd
✅ CRDs Status: Compatible

Compatibility Analysis:
- applications.argoproj.io: v1alpha1 → v1alpha1 ✅
- appprojects.argoproj.io: v1alpha1 → v1alpha1 ✅
- applicationsets.argoproj.io: v1alpha1 → v1alpha1 ✅

Recommendations:
- Safe to upgrade to v2.11.3
- No breaking changes detected
- Backup recommended before upgrade
```

## 🔍 ArgoCD Inspector

### Descripción
Realiza una inspección completa de la configuración actual de ArgoCD y genera un reporte detallado.

### Ubicación
`Check_resources_and_healthcheck/inspect_argocd.sh`

### Uso
```bash
# Inspección completa
./Check_resources_and_healthcheck/inspect_argocd.sh

# Generar solo reporte de configuración
./Check_resources_and_healthcheck/inspect_argocd.sh --config-only

# Incluir análisis de recursos
./Check_resources_and_healthcheck/inspect_argocd.sh --include-resources
```

### Características Avanzadas
- **Extracción de Valores**: server.url, dex.config, policy.csv
- **Health Checks**: Evaluación de livenessProbe y readinessProbe
- **Análisis de Recursos**: Uso actual de CPU/Memory
- **Parámetros Problemáticos**: Identificación con advertencias
- **Exportación**: Reporte completo en Markdown

### Reporte Generado
```markdown
# ArgoCD Inspection Report

## System Information
- Cluster: production-eks
- Namespace: argocd
- Installation Method: Helm
- Chart Version: 5.46.8
- App Version: v2.8.4

## Configuration Analysis
- Server URL: https://argocd.company.com
- Authentication: SSO enabled (OIDC)
- RBAC: Custom policies configured
- TLS: Enabled with valid certificates

## Health Status
- Controller: ✅ Healthy
- Server: ✅ Healthy  
- Repo Server: ✅ Healthy
- Redis: ✅ Healthy
- Dex: ✅ Healthy

## Resource Utilization
- CPU Usage: 45% of limits
- Memory Usage: 67% of limits
- Storage: 12GB used of 50GB
```

## ✅ Pre-update Check

### Descripción
Ejecuta una serie de validaciones antes de actualizar ArgoCD para asegurar que el sistema esté listo.

### Ubicación
`Pre-update_check/pre-validation.sh`

### Uso
```bash
# Validación completa pre-actualización
./Pre-update_check/pre-validation.sh

# Validación específica de Redis HA
./Pre-update_check/pre-validation.sh --redis-only

# Modo rápido (sin análisis detallado)
./Pre-update_check/pre-validation.sh --quick
```

### Características Mejoradas
- **Verificación de Redis HA**: Análisis específico de conectividad
- **Estado de Aplicaciones**: Sync status y health status
- **Reinicios de Pods**: Detecta pods con reinicios recientes
- **Conectividad Redis**: Test con autenticación
- **Prevención de Falsos Positivos**: Funciones mejoradas de validación

### Checklist de Validación
```bash
Pre-Update Validation Report:

🔍 System Health Checks:
✅ All ArgoCD pods are running
✅ No recent pod restarts detected
✅ Redis HA connectivity verified
✅ External connectivity working

📊 Application Status:
✅ 45/47 applications synced (95.7%)
⚠️  2 applications out of sync (non-critical)
✅ No degraded applications
✅ No failed sync operations

🔧 Resource Status:
✅ CPU usage within limits (< 80%)
✅ Memory usage acceptable (< 90%)
✅ Storage availability sufficient
✅ Network policies functional

🚦 Pre-Update Decision: ✅ SAFE TO PROCEED
```

## 🛠️ Herramientas Especializadas

### CRD Compatibility Checker
```bash
# Verificar compatibilidad específica
./Check_CRDs-K8s/argocd-crd-checker/check_crds_argocd.sh --version v2.11.3

# Análisis detallado con logs
./Check_CRDs-K8s/argocd-crd-checker/check_crds_argocd.sh --detailed --log-level debug
```

### Argo Rollouts Integration
```bash
# Verificar sincronización con Argo Rollouts
./Check_CRDs-K8s/check_crds-argocd.sh --include-rollouts

# Análisis de compatibilidad cruzada
./Check_CRDs-K8s/check_crds-argocd.sh --cross-compatibility
```

## 📊 Análisis Avanzado

### Health Score Calculation
```bash
# Cálculo de puntuación de salud
Health Score: 94/100

Desglose:
- Pod Health: 100/100 ✅
- Application Sync: 90/100 ⚠️
- Resource Usage: 85/100 ⚠️
- Security Config: 100/100 ✅
- Performance: 95/100 ✅
```

### Métricas de Rendimiento
- **Tiempo de Sincronización**: Promedio 12s
- **API Response Time**: < 200ms
- **Repository Scan**: Cada 3 minutos
- **Webhook Latency**: < 100ms

## 🚨 Alertas y Problemas Comunes

### Problemas de CRDs
```bash
❌ CRD Version Mismatch Detected:
- applications.argoproj.io: v1alpha1 (current) vs v1beta1 (required)
- Recommendation: Update CRDs before ArgoCD upgrade

⚠️ API Deprecation Warning:
- networking.k8s.io/v1beta1 will be removed in K8s 1.25+
- Update Ingress resources to networking.k8s.io/v1
```

### Issues de Configuración
```bash
⚠️ Configuration Issues Found:
- server.insecure: true (should be false in production)
- dex.config.issuer: http:// (should use https://)
- rbac.policy.default: role:admin (too permissive)

🔧 Recommendations:
- Enable TLS termination
- Configure proper OIDC issuer
- Implement least-privilege RBAC
```

## 📈 Reporting y Exportación

### Formatos de Reporte
```bash
# Exportar en diferentes formatos
./inspect_argocd.sh --format markdown > report.md
./inspect_argocd.sh --format json > report.json
./inspect_argocd.sh --format yaml > report.yaml
```

### Integración con Monitoring
```bash
# Exportar métricas para Prometheus
./inspect_argocd.sh --prometheus-metrics > argocd_metrics.prom

# Webhook para Slack/Teams
./inspect_argocd.sh --webhook https://hooks.slack.com/...
```

## 🔄 Automatización

### Validaciones Programadas
```bash
# Crontab para validaciones diarias
0 6 * * * /path/to/Pre-update_check/pre-validation.sh --auto-report

# Alertas automáticas si hay problemas
0 */4 * * * /path/to/Check_CRDs-K8s/check_crds-argocd.sh --alert-on-issues
```

### CI/CD Integration
```yaml
# GitHub Actions workflow
- name: ArgoCD Validation
  run: |
    ./Pre-update_check/pre-validation.sh
    if [ $? -ne 0 ]; then
      echo "Validation failed, blocking deployment"
      exit 1
    fi
```

## 📞 Troubleshooting

### Si las validaciones fallan:
1. **Revisar logs detallados**: `--verbose` flag
2. **Verificar conectividad**: kubectl cluster-info
3. **Comprobar permisos**: RBAC para namespace argocd
4. **Analizar recursos**: CPU/Memory disponibles

### Escalación:
- **Nivel 1**: Reintentar validación con `--force-refresh`
- **Nivel 2**: Ejecutar herramientas individualmente
- **Nivel 3**: Contactar equipo de DevOps con logs completos