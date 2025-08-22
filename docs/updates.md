# Herramientas de Actualización

Esta sección describe las herramientas para actualizar ArgoCD y sus CRDs de forma segura.

## 🔄 Safe CRD Upgrade

### Descripción
Herramienta TUI (Terminal User Interface) para actualizar CRDs de ArgoCD de forma segura con interfaz interactiva.

### Ubicación
`Check_crds_compatibilitie/safe_crd_upgrade_tui.sh`

### Características Destacadas
- **Menú Interactivo**: Las últimas 10 versiones de ArgoCD desde GitHub
- **Clonación Automática**: Descarga el repo de ArgoCD en la versión elegida
- **Backup Automático**: Respaldo de CRDs actuales antes de actualizar
- **Diff Visualization**: Comparación vs versión actual antes de aplicar
- **Validación**: Verificación con recursos existentes

### Uso
```bash
# Ejecutar interfaz TUI
./Check_crds_compatibilitie/safe_crd_upgrade_tui.sh

# Modo no interactivo con versión específica
./Check_crds_compatibilitie/safe_crd_upgrade_tui.sh --version v2.11.3

# Solo backup sin actualizar
./Check_crds_compatibilitie/safe_crd_upgrade_tui.sh --backup-only
```

### Flujo de Trabajo TUI
```bash
🔄 ArgoCD Safe CRD Upgrade Tool
=====================================

📋 Available Versions:
[1] v2.11.3 (Latest Stable)
[2] v2.11.2
[3] v2.11.1  
[4] v2.11.0
[5] v2.10.9
[6] v2.10.8
[7] v2.10.7
[8] v2.10.6
[9] v2.10.5
[10] v2.10.4

Select version to upgrade to: 1

🔍 Selected: v2.11.3
📥 Downloading ArgoCD manifests...
💾 Creating backup of current CRDs...
📊 Analyzing differences...

🔧 Changes Summary:
- applications.argoproj.io: Minor schema updates
- appprojects.argoproj.io: New optional fields
- applicationsets.argoproj.io: Enhanced spec

⚠️  Breaking Changes: None detected
✅ Validation: All existing resources compatible

Proceed with upgrade? [y/N]: y
```

### Backup Management
```bash
# Ubicación de backups
crd_backups/
├── backup_20250822_143025/
│   ├── applications.argoproj.io.yaml
│   ├── appprojects.argoproj.io.yaml
│   ├── applicationsets.argoproj.io.yaml
│   └── backup_metadata.json

# Restaurar desde backup
./safe_crd_upgrade_tui.sh --restore backup_20250822_143025
```

## 🔧 CRD Updater

### Descripción
Herramienta especializada para actualizar CRDs a versiones específicas con configuración avanzada.

### Ubicación
`Update_argocd_crds/argocd-crd-updater.sh`

### Características Avanzadas
- **Configuración Específica**: Optimizado para versión v2.14.11
- **Backup con Timestamp**: Directorios organizados por fecha/hora
- **Descarga Automática**: CRDs desde repositorio oficial de ArgoCD
- **Verificación de Esquemas**: Validación de compatibilidad
- **Rollback Automático**: En caso de fallo durante la actualización

### Uso
```bash
# Actualización estándar
./Update_argocd_crds/argocd-crd-updater.sh

# Actualización a versión específica
./Update_argocd_crds/argocd-crd-updater.sh --version v2.11.3

# Modo dry-run (simulación)
./Update_argocd_crds/argocd-crd-updater.sh --dry-run

# Forzar actualización (sin confirmaciones)
./Update_argocd_crds/argocd-crd-updater.sh --force
```

### Proceso de Actualización
```bash
🔧 ArgoCD CRD Updater
=====================

📋 Current Status:
- ArgoCD Version: v2.10.9
- CRDs Version: v2.10.9
- Target Version: v2.11.3

🔍 Pre-flight Checks:
✅ Kubernetes connectivity
✅ Permissions verified
✅ ArgoCD namespace accessible
✅ Current CRDs backup ready

📥 Download Phase:
- Fetching CRDs from: github.com/argoproj/argo-cd/v2.11.3
- Validating checksums
- Extracting manifests

🔄 Update Phase:
[1/4] Updating applications.argoproj.io... ✅
[2/4] Updating appprojects.argoproj.io... ✅  
[3/4] Updating applicationsets.argoproj.io... ✅
[4/4] Updating workflows.argoproj.io... ✅

✅ CRD Update Completed Successfully!

🔍 Post-Update Validation:
- Schema validation: ✅ Passed
- Existing resources: ✅ Compatible
- API endpoints: ✅ Responsive
```

## 📊 Verificación de CRDs Actuales

### Check Current CRDs
```bash
# Verificar estado actual
./Update_argocd_crds/check-current-crds.sh

# Comparar con versión objetivo
./Update_argocd_crds/check-current-crds.sh --compare v2.11.3

# Listar todas las versiones disponibles
./Update_argocd_crds/check-current-crds.sh --list-versions
```

### Reporte de Estado
```bash
Current CRD Status Report:
=========================

📦 Installed CRDs:
- applications.argoproj.io (v1alpha1) - v2.10.9
- appprojects.argoproj.io (v1alpha1) - v2.10.9
- applicationsets.argoproj.io (v1alpha1) - v2.10.9

🔍 Schema Analysis:
- Total Fields: 847
- Required Fields: 23
- Optional Fields: 824
- Deprecated Fields: 2

⚠️  Deprecation Warnings:
- spec.source.path (use spec.sources[].path)
- spec.destination.namespace (use spec.destinations[].namespace)

🎯 Upgrade Recommendations:
- Target: v2.11.3
- Breaking Changes: None
- Migration Required: No
- Estimated Downtime: < 30 seconds
```

## 🛡️ Estrategias de Actualización

### Actualización Blue-Green
```bash
# Paso 1: Crear namespace temporal
kubectl create namespace argocd-upgrade

# Paso 2: Instalar nueva versión en paralelo
helm install argocd-new argo/argo-cd --version 5.51.6 -n argocd-upgrade

# Paso 3: Migrar configuración
./migrate-config.sh argocd argocd-upgrade

# Paso 4: Switch de tráfico
./switch-traffic.sh argocd-upgrade argocd

# Paso 5: Cleanup
kubectl delete namespace argocd-old
```

### Actualización Rolling
```bash
# Paso 1: Actualizar CRDs primero
./safe_crd_upgrade_tui.sh --version v2.11.3

# Paso 2: Actualizar ArgoCD gradualmente
helm upgrade argocd argo/argo-cd --version 5.51.6 -n argocd --wait

# Paso 3: Verificar componente por componente
./verify-component.sh controller
./verify-component.sh server
./verify-component.sh repo-server
```

## 🔙 Rollback y Recuperación

### Rollback Automático
```bash
# En caso de fallo, rollback automático
./argocd-crd-updater.sh --rollback-on-failure

# Rollback manual a backup específico
./safe_crd_upgrade_tui.sh --restore backup_20250822_143025

# Verificar estado después del rollback
./check-current-crds.sh --validate
```

### Recuperación de Emergencia
```bash
# Escenario: CRDs corruptos
# 1. Restore desde backup
kubectl apply -f crd_backups/backup_20250822_143025/

# 2. Restart ArgoCD components
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart statefulset/argocd-application-controller -n argocd

# 3. Verificar estado
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

## 🔧 Configuración Avanzada

### Variables de Entorno
```bash
# Configuración personalizada
export ARGOCD_NAMESPACE=argocd
export BACKUP_RETENTION_DAYS=30
export CRD_DOWNLOAD_TIMEOUT=300
export VALIDATION_TIMEOUT=60

# URLs personalizadas
export ARGOCD_REPO_URL="https://github.com/argoproj/argo-cd"
export CRD_MANIFEST_PATH="/manifests/crds"
```

### Configuración de Backup
```bash
# Configurar retención de backups
cat > backup_config.yaml <<EOF
retention:
  days: 30
  max_backups: 50
  compress: true
location:
  path: /backup/argocd-crds
  s3_bucket: company-argocd-backups
notification:
  slack_webhook: https://hooks.slack.com/...
  email: devops@company.com
EOF
```

## 📈 Monitoreo de Actualizaciones

### Métricas Post-Actualización
```bash
# Verificar métricas después de actualizar
kubectl top pods -n argocd
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Verificar logs de componentes
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd --tail=100
kubectl logs -l app.kubernetes.io/name=argocd-application-controller -n argocd --tail=100
```

### Alertas de Actualización
```bash
# Configurar alertas para actualizaciones
cat > update_alerts.yaml <<EOF
alerts:
  - name: CRD_Update_Failed
    condition: exit_code != 0
    action: send_slack_alert
  - name: Long_Update_Time
    condition: duration > 300s
    action: send_email_alert
  - name: High_Resource_Usage
    condition: cpu_usage > 80%
    action: scale_up_resources
EOF
```

## 🚀 Mejores Prácticas

### Pre-Actualización
1. **Backup Completo**: Siempre crear backup antes de actualizar
2. **Testing**: Probar en entorno de staging primero
3. **Maintenance Window**: Programar en horario de bajo tráfico
4. **Communication**: Notificar a teams afectados

### Durante la Actualización
1. **Monitoreo**: Vigilar métricas en tiempo real
2. **Rollback Plan**: Tener plan de rollback listo
3. **Logs**: Mantener logs detallados
4. **Validation**: Verificar cada paso antes de continuar

### Post-Actualización
1. **Verification**: Validar funcionalidad completa
2. **Performance**: Verificar que el rendimiento sea óptimo
3. **Documentation**: Documentar cambios realizados
4. **Cleanup**: Limpiar recursos temporales

## 📞 Soporte

### Escalación de Problemas
- **Nivel 1**: Rollback automático activado
- **Nivel 2**: Intervención manual requerida
- **Nivel 3**: Contactar con equipo de ArgoCD upstream

### Recursos Adicionales
- [ArgoCD Release Notes](https://github.com/argoproj/argo-cd/releases)
- [Breaking Changes Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/)
- [CRD Migration Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/)