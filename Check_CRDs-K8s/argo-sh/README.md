# Script de Validación de CRDs de ArgoCD

Este script automatiza la validación del estado de los Custom Resource Definitions (CRDs) de ArgoCD, ayudándote a determinar si necesitas actualizar los CRDs o si tu instalación está funcionando correctamente.

## 🎯 Propósito

El script analiza tu instalación de ArgoCD para:
- Verificar la compatibilidad entre la versión del servidor y los CRDs
- Detectar problemas relacionados con APIs obsoletas
- Evaluar el estado general de tus aplicaciones
- Proporcionar recomendaciones específicas sobre actualizaciones

## 📋 Características

### ✅ Validaciones Incluidas
- **Información del servidor ArgoCD**: Versión, imagen, deployment status
- **Estado de CRDs**: Versiones, compatibilidad, fechas de creación
- **Recursos de API**: Disponibilidad y versiones soportadas
- **Estado de aplicaciones**: Conteo por estado (Synced, Healthy, OutOfSync, etc.)
- **Análisis de logs**: Búsqueda de errores relacionados con CRDs y APIs
- **Detección de imágenes personalizadas**: Identifica instalaciones custom

### 🔍 Detección Inteligente
- Identifica imágenes personalizadas (ECR, registries privados)
- Detecta errores de compatibilidad de APIs
- Evalúa la necesidad real de actualización
- Proporciona recomendaciones contextuales

## 🚀 Instalación y Uso

### Prerrequisitos
- `kubectl` configurado y con acceso al cluster
- Permisos para leer recursos en el namespace de ArgoCD
- Bash 4.0 o superior

### Instalación

```bash
# Clonar o descargar el script
curl -O https://example.com/argocd_crd_validation.sh

# Hacer ejecutable
chmod +x argocd_crd_validation.sh

# El script creará automáticamente la carpeta ./logs/ en la primera ejecución
```

### Uso Básico

```bash
# Ejecutar con configuración por defecto (namespace 'argocd')
./argocd_crd_validation.sh
```

### Configuración Personalizada

```bash
# Especificar un namespace diferente
NAMESPACE=mi-argocd ./argocd_crd_validation.sh

# Cambiar la ubicación del log (opcional)
LOG_FILE=/custom/path/validation.log ./argocd_crd_validation.sh

# Por defecto, los logs se guardan en ./logs/ relativo al script
```

## 📊 Interpretación de Resultados

### Estados de Salida
- **✅ Verde**: Todo funcionando correctamente
- **🟡 Amarillo**: Advertencias que requieren atención
- **🔴 Rojo**: Errores críticos que necesitan resolución inmediata

### Secciones del Reporte

#### 1. Información del Servidor ArgoCD
```
📦 Imagen del servidor: registry.com/argocd:v2.8.4
🏷️  Versión extraída: v2.8.4
```

#### 2. Información de los CRDs
```
🔍 Analizando CRD: applications.argoproj.io
✓ CRD existe
  📋 Administrado por: Helm
  🏷️  Versión etiquetada: v2.8.4
  🔌 Versiones de API: v1alpha1
```

#### 3. Estado de las Aplicaciones
```
📊 Total de aplicaciones: 150
✅ Aplicaciones sincronizadas: 145
🟢 Aplicaciones saludables: 148
🟡 Aplicaciones fuera de sincronización: 5
🔴 Aplicaciones degradadas: 2
```

#### 4. Recomendaciones
El script proporciona recomendaciones específicas basadas en:
- Tipo de imagen (oficial vs personalizada)
- Estado general de las aplicaciones
- Errores encontrados en logs
- Compatibilidad de versiones

## 🔧 Configuración Avanzada

### Variables de Entorno

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `NAMESPACE` | Namespace donde está instalado ArgoCD | `argocd` |
| `LOG_FILE` | Ubicación del archivo de log (opcional) | `./logs/argocd_crd_validation_TIMESTAMP.log` |

### Personalización

```bash
# Ejemplo de configuración personalizada
export NAMESPACE="argocd-system"
export LOG_FILE="/var/log/argocd-validation.log"  # Opcional - por defecto usa ./logs/
./argocd_crd_validation.sh
```

## 📝 Archivos de Salida

### Estructura de Directorios
El script crea automáticamente la siguiente estructura:

```
tu-directorio/
├── argocd_crd_validation.sh
└── logs/
    ├── argocd_crd_validation_20250724_095730.log
    ├── argocd_crd_validation_20250724_101245.log
    └── argocd_crd_validation_20250724_143022.log
```

### Log Detallado
Por defecto, los logs se guardan en:
```
./logs/argocd_crd_validation_YYYYMMDD_HHMMSS.log
```

**Ventajas de esta estructura:**
- ✅ **Organizado**: Todos los logs en una carpeta dedicada
- ✅ **Portátil**: Funciona independiente de donde ejecutes el script
- ✅ **Histórico**: Mantiene un registro de todas las ejecuciones
- ✅ **Limpio**: No llena directorios temporales del sistema

### Contenido del Log
- Salida completa de todos los comandos ejecutados
- Errores detallados y stack traces
- Información adicional para debugging
- Timestamps de cada operación

## 🔍 Casos de Uso Comunes

### Caso 1: Instalación Estándar
```bash
# ArgoCD instalado con Helm oficial
./argocd_crd_validation.sh
# ✅ Resultado: Probablemente no necesitas actualizar CRDs
# 📁 Log guardado en: ./logs/argocd_crd_validation_20250724_095730.log
```

### Caso 2: Imagen Personalizada
```bash
# ArgoCD con imagen custom de ECR/registry privado
./argocd_crd_validation.sh
# ⚠️ Resultado: Consultar con equipo antes de actualizar
# 📁 Log guardado en: ./logs/argocd_crd_validation_20250724_101245.log
```

### Caso 3: Problemas de Sincronización
```bash
# Muchas aplicaciones OutOfSync o con errores
./argocd_crd_validation.sh
# 🔴 Resultado: Resolver problemas antes de actualizar CRDs
# 📁 Log guardado en: ./logs/argocd_crd_validation_20250724_143022.log
```

## 🛠️ Troubleshooting

### Errores Comunes

#### Error: Namespace no encontrado
```bash
Error: El namespace 'argocd' no existe
```
**Solución**: Especificar el namespace correcto
```bash
NAMESPACE=tu-namespace ./argocd_crd_validation.sh
```

#### Error: Permisos insuficientes
```bash
Error: cannot list deployments.apps in namespace "argocd"
```
**Solución**: Verificar permisos RBAC
```bash
kubectl auth can-i get deployments -n argocd
```

#### Error: kubectl no encontrado
```bash
Error: kubectl no está instalado
```
**Solución**: Instalar kubectl
```bash
# En macOS
brew install kubectl

# En Ubuntu/Debian
sudo apt-get install kubectl
```

### Debug Mode

Para ejecutar en modo debug:
```bash
# Habilitar debug de bash
bash -x ./argocd_crd_validation.sh

# Ver logs en tiempo real
tail -f ./logs/argocd_crd_validation_*.log

# Ver el último log generado
ls -t ./logs/ | head -1 | xargs -I {} tail -f ./logs/{}
```

## 📚 Recursos Adicionales

### Documentación Oficial
- [ArgoCD CRDs Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/custom-resource-definitions/)
- [Kubernetes CRDs](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

### Gestión de Logs

```bash
# Ver todos los logs disponibles
ls -la ./logs/

# Ver el log más reciente
ls -t ./logs/ | head -1 | xargs -I {} cat ./logs/{}

# Limpiar logs antiguos (mantener solo los últimos 5)
ls -t ./logs/ | tail -n +6 | xargs -I {} rm ./logs/{}

# Buscar errores en todos los logs
grep -r "ERROR\|CRITICAL" ./logs/

# Comprimir logs antiguos
find ./logs/ -name "*.log" -mtime +7 -exec gzip {} \;
```

### Comandos Útiles
```bash
# Verificar versión de ArgoCD
kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'

# Listar todos los CRDs de ArgoCD
kubectl get crd | grep argoproj.io

# Ver aplicaciones con problemas
kubectl get applications.argoproj.io -A | grep -E "(OutOfSync|Degraded)"
```

## 🤝 Contribución

### Reportar Issues
Si encuentras problemas o tienes sugerencias:
1. Ejecuta el script con debug habilitado
2. Incluye el log completo (ubicado en `./logs/`)
3. Especifica tu versión de ArgoCD y Kubernetes
4. Comparte la salida del comando: `ls -la ./logs/`

### Mejoras Sugeridas
- Soporte para ArgoCD en múltiples namespaces
- Integración con sistemas de monitoreo
- Exportación de métricas
- Validación de manifiestos YAML

## 📄 Licencia

Este script se proporciona bajo licencia MIT. Úsalo libremente en tus proyectos.

## 🏷️ Versión

**Versión**: 1.0.0  
**Última actualización**: Julio 2025  
**Compatibilidad**: ArgoCD 2.0+, Kubernetes 1.19+

---

**⚠️ Nota Importante**: Este script es una herramienta de diagnóstico. Siempre realiza backups antes de actualizar componentes críticos como los CRDs de ArgoCD.