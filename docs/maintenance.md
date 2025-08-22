# Herramientas de Mantenimiento

Esta sección describe las herramientas disponibles para el mantenimiento rutinario de ArgoCD.

## 🔧 Redis HA Fix

### Descripción
Herramienta para diagnosticar y reparar problemas comunes en Redis HA (High Availability) en clusters ArgoCD.

### Ubicación
`Check-Redis-ha/redis-ha-fix.sh`

### Uso
```bash
# Ejecutar diagnóstico completo
./Check-Redis-ha/redis-ha-fix.sh --diagnose

# Reparar problemas detectados
./Check-Redis-ha/redis-ha-fix.sh --fix

# Modo verbose para debugging
./Check-Redis-ha/redis-ha-fix.sh --diagnose --verbose
```

### Problemas que Detecta
- **Conexiones Redis**: Verifica conectividad entre pods
- **Configuración HA**: Valida setup de alta disponibilidad
- **Memoria y Performance**: Analiza uso de recursos
- **Logs de Error**: Detecta patrones de error comunes

### Resultados
- Report detallado de estado
- Recomendaciones de reparación
- Scripts de fix automático

## 🧹 Zombie Cleaner

### Descripción
Limpia AppProjects con finalizers atorados que impiden su eliminación correcta.

### Ubicación
`Check-argocd/argocd-zombie-cleaner.sh`

### Uso
```bash
# Listar recursos zombie
./Check-argocd/argocd-zombie-cleaner.sh --list

# Limpiar recursos específicos
./Check-argocd/argocd-zombie-cleaner.sh --clean --namespace argocd

# Modo dry-run para preview
./Check-argocd/argocd-zombie-cleaner.sh --clean --dry-run
```

### Recursos que Limpia
- **AppProjects**: Con finalizers atorados
- **Applications**: En estado de eliminación pendiente
- **Repositories**: Con referencias rotas
- **ConfigMaps**: Huérfanos sin owner

### Precauciones
- ⚠️ **Backup automático** antes de limpiar
- ⚠️ **Confirmación requerida** para operaciones destructivas
- ⚠️ **Logs detallados** de todas las operaciones

## 🔄 Mantenimiento Rutinario

### Checklist Semanal
- [ ] Ejecutar Redis HA diagnostics
- [ ] Revisar logs de ArgoCD controller
- [ ] Limpiar recursos zombie
- [ ] Verificar sincronización de repositorios
- [ ] Revisar métricas de performance

### Checklist Mensual
- [ ] Backup completo de configuración
- [ ] Actualización de CRDs si disponible
- [ ] Limpieza de logs antiguos
- [ ] Revisión de seguridad
- [ ] Performance analysis completo

### Automatización
```bash
# Script de mantenimiento automático
#!/bin/bash
# maintenance-routine.sh

# Redis HA Check
./Check-Redis-ha/redis-ha-fix.sh --diagnose

# Zombie Cleanup
./Check-argocd/argocd-zombie-cleaner.sh --clean --auto-confirm

# Performance Report
./Performance_monitor/performance_monitor.sh --generate-report
```

## 📊 Monitoreo

### Métricas Clave
- **Redis Connections**: Número de conexiones activas
- **Application Sync**: Tasa de sincronización exitosa
- **Resource Usage**: CPU/Memory de componentes
- **Error Rate**: Tasa de errores en operaciones

### Alertas Recomendadas
- Redis conexiones > 80% capacity
- Aplicaciones failed sync > 5%
- Memory usage > 85%
- Error rate > 2%

## 🚨 Troubleshooting

### Problemas Comunes

#### Redis HA no responde
```bash
# Diagnóstico
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-redis-ha

# Fix común
kubectl rollout restart statefulset/argocd-redis-ha-server -n argocd
```

#### AppProjects atorados
```bash
# Identificar finalizers
kubectl get appproject -o yaml | grep -A5 finalizers

# Remover finalizers manualmente (último recurso)
kubectl patch appproject myproject --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

## 📞 Soporte

Para problemas específicos de mantenimiento:
- **Escalación**: British Airways DevOps Team
- **Logs**: Siempre incluir logs completos
- **Contexto**: Estado del cluster antes del problema