# 🚀 Argo CD CRDs Compatibility Analyzer for EKS

Un script completo para analizar la compatibilidad entre los Custom Resource Definitions (CRDs) de Argo CD y tus componentes instalados en Amazon EKS, diseñado para mantener un proceso de actualización seguro y controlado.

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Instalación](#-instalación)
- [Uso](#-uso)
- [Interpretación de Resultados](#-interpretación-de-resultados)
- [Casos de Uso Comunes](#-casos-de-uso-comunes)
- [Solución de Problemas](#-solución-de-problemas)
- [Mejores Prácticas](#-mejores-prácticas)
- [Contribuir](#-contribuir)

## ✨ Características

### 🔍 **Análisis Integral**
- ✅ Detección automática de instalaciones Argo CD (Helm y manual)
- ✅ Verificación de compatibilidad de CRDs vs versión de aplicación
- ✅ Análisis de sincronización entre Argo CD y Argo Rollouts
- ✅ Información detallada del cluster EKS
- ✅ Recomendaciones específicas de actualización

### 🎨 **Interfaz Visual**
- 📊 Tablas formateadas con colores e iconos
- ⚠️ Códigos de estado visual intuitivos
- 🎯 Mensajes de error y advertencia claros
- 📈 Resumen ejecutivo con plan de acción

### 🛠️ **Gestión de Actualizaciones**
- 🔄 Plan paso a paso para actualizaciones seguras
- 💾 Comandos de backup automático
- 🎯 Verificaciones pre y post actualización
- 🔐 Consideraciones específicas para EKS

## 📦 Requisitos

### Herramientas Necesarias
```bash
# Verificar que tienes las herramientas instaladas
kubectl version --client
helm version
aws --version
jq --version
```

### Dependencias del Sistema
- **kubectl**: Cliente de Kubernetes configurado para tu cluster EKS
- **helm**: Cliente Helm v3+ (si usas instalación Helm)
- **aws-cli**: Para detección automática de información EKS
- **jq**: Para procesamiento de JSON
- **bash**: Version 4.0 o superior

### Permisos Requeridos
```yaml
# Permisos mínimos de Kubernetes necesarios:
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crd-analyzer
rules:
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["namespaces", "pods"]
  verbs: ["get", "list"]
- apiGroups: ["argoproj.io"]
  resources: ["applications", "applicationsets", "appprojects"]
  verbs: ["get", "list"]
```

## 🛠️ Instalación

### Descarga Directa
```bash
# Clonar el repositorio
git clone <repo-url>
cd Check_CRDs-K8s

# Hacer ejecutable
chmod +x check_crds-argocd.sh
```

### Instalación de Dependencias

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y jq curl

# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Instalar Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### macOS
```bash
# Usando Homebrew
brew install kubectl helm awscli jq
```

#### RHEL/CentOS
```bash
sudo yum install -y jq curl
# Seguir instrucciones de instalación específicas para kubectl, helm, aws-cli
```

## 🚀 Uso

### Uso Básico
```bash
# Ejecutar análisis completo
./check_crds-argocd.sh
```

### Configuración del Contexto
```bash
# Asegurarte de estar en el contexto correcto
kubectl config current-context
kubectl config use-context <tu-cluster-eks>

# Verificar acceso al namespace de Argo CD
kubectl get pods -n argocd
```

### Ejecución con Logging
```bash
# Guardar output para análisis posterior
./check_crds-argocd.sh | tee argo-crd-analysis-$(date +%Y%m%d).log
```

## 📊 Interpretación de Resultados

### Códigos de Estado

| Icono | Estado | Significado | Acción Requerida |
|-------|--------|-------------|------------------|
| ✅ | Compatible | CRD totalmente compatible | Ninguna |
| ⚠️ | Requiere Actualización | Funcional pero desactualizado | Planificar actualización |
| ❌ | Incompatible | Problema crítico | Acción inmediata |
| ℹ️ | Información | Dato relevante | Revisar |

### Análisis de Compatibilidad

#### 🟢 **Applications CRD - Compatible Completo**
```
✨ Compatible completo | OK | Soporta ambas APIs necesarias
```
- **Significado**: CRD soporta v1alpha1 y v1beta1
- **Acción**: Ninguna, sistema funcionando correctamente

#### 🟡 **Applications CRD - Requiere Actualización**
```
⚠️ Requiere actualización | ACTUALIZAR | Falta soporte v1beta1
```
- **Significado**: Solo soporta v1alpha1, falta v1beta1
- **Impacto**: Argo CD 2.5+ requiere v1beta1 para nuevas funcionalidades
- **Acción**: Actualizar CRDs antes que la aplicación

#### 🔴 **CRD Incompatible**
```
💥 Incompatible | CRÍTICO | CRD corrupto o versión muy antigua
```
- **Significado**: CRD faltante o completamente incompatible
- **Impacto**: Funcionalidad no disponible
- **Acción**: Reinstalación inmediata requerida

### Análisis de Sincronización
```
⚠️ Desincronización detectada:
• Argo CD CRDs:      2024-04-10
• Argo Rollouts CRDs: 2025-02-18
• Diferencia:         314 días
```
- **Significado**: CRDs instalados en fechas muy diferentes
- **Riesgo**: Posibles incompatibilidades entre componentes
- **Acción**: Sincronizar actualizaciones

## 🎯 Casos de Uso Comunes

### 1. **Pre-actualización de Argo CD**
```bash
# ANTES de actualizar Argo CD
./check_crds-argocd.sh

# Si hay incompatibilidades, seguir el plan de actualización mostrado
# DESPUÉS actualizar Argo CD
helm upgrade argocd argo/argo-cd -n argocd

# Verificar que todo funcionó correctamente
./check_crds-argocd.sh
```

### 2. **Resolución de Problemas Post-actualización**
```bash
# Si después de una actualización hay problemas
./check_crds-argocd.sh

# El script mostrará exactamente qué CRDs necesitan atención
# Seguir las recomendaciones específicas mostradas
```

### 3. **Auditoría Regular del Sistema**
```bash
# Crear un cron job para verificaciones regulares
# Añadir a crontab:
0 9 * * 1 /path/to/check_crds-argocd.sh > /var/log/argo-crd-weekly-$(date +\%Y\%m\%d).log 2>&1
```

### 4. **Migración entre Versiones**
```bash
# Antes de migrar a una nueva versión mayor
./check_crds-argocd.sh > pre-migration-analysis.log

# Seguir el plan de actualización
# Después de la migración
./check_crds-argocd.sh > post-migration-analysis.log

# Comparar resultados
diff pre-migration-analysis.log post-migration-analysis.log
```

## 🔧 Solución de Problemas

### Error: "Namespace 'argocd' no encontrado"
```bash
# Verificar que Argo CD está instalado
kubectl get namespaces | grep argo

# Si está en otro namespace, modificar la variable en el script:
ARGOCD_NAMESPACE="tu-namespace-argo"
```

### Error: "No se pudo determinar la versión"
```bash
# Verificar que los pods de Argo CD están corriendo
kubectl get pods -n argocd

# Verificar las etiquetas de los pods
kubectl get pods -n argocd --show-labels
```

### Error: "declare: -A: invalid option"
```bash
# Este error ocurre en versiones de bash < 4.0 (común en macOS)
# Verificar versión de bash
bash --version

# En macOS, actualizar bash:
brew install bash
# Luego cambiar el shebang del script a:
#!/usr/local/bin/bash

# O usar el script tal como está - ya incluye compatibilidad con bash 3.x
```

### Error: "date: illegal option -- d"
```bash
# Este error es común en macOS donde el comando date es diferente
# El script ya incluye compatibilidad usando Python como alternativa

# Verificar que tienes Python disponible:
python3 --version
# o
python --version

# Si no tienes Python, instálalo:
# macOS
brew install python3

# Ubuntu/Debian  
sudo apt install python3
```

### Error: "No se detecta versión de Kubernetes"
```bash
# Verificar conectividad al cluster
kubectl cluster-info

# Verificar permisos
kubectl auth can-i get pods --namespace argocd

# Si usas un contexto específico
kubectl config use-context <tu-contexto-eks>
```

### CRDs Muestran como Incompatibles Incorrectamente
```bash
# Verificar manualmente las versiones de API
kubectl get crd applications.argoproj.io -o yaml | grep -A 10 "versions:"

# Verificar que el CRD está establecido correctamente
kubectl get crd applications.argoproj.io -o jsonpath='{.status.conditions}'
```

### Problemas de Permisos
```bash
# Verificar permisos actuales
kubectl auth can-i get customresourcedefinitions
kubectl auth can-i list pods --namespace argocd

# Si falta algún permiso, contactar al administrador del cluster
```

## 📋 Mejores Prácticas

### 🔄 **Proceso de Actualización Recomendado**

1. **Pre-actualización**:
   ```bash
   # Ejecutar análisis
   ./check_crds-argocd.sh
   
   # Backup de configuraciones críticas
   kubectl get applications -n argocd -o yaml > backup-applications.yaml
   kubectl get appprojects -n argocd -o yaml > backup-projects.yaml
   ```

2. **Actualización de CRDs**:
   ```bash
   # SIEMPRE actualizar CRDs primero
   curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/application-crd.yaml | kubectl apply -f -
   curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/applicationset-crd.yaml | kubectl apply -f -
   curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/appproject-crd.yaml | kubectl apply -f -
   ```

3. **Actualización de la aplicación**:
   ```bash
   # Actualizar via Helm
   helm repo update
   helm upgrade argocd argo/argo-cd -n argocd --reuse-values --wait --timeout=600s
   ```

4. **Post-actualización**:
   ```bash
   # Verificar estado
   ./check_crds-argocd.sh
   kubectl get pods -n argocd
   kubectl get applications -n argocd
   ```

### 📅 **Calendario de Mantenimiento**

- **Semanal**: Ejecutar script para verificar estado
- **Mensual**: Revisar actualizaciones disponibles
- **Trimestral**: Actualización planificada si hay nuevas versiones
- **Antes de cambios críticos**: Análisis completo

### 🔐 **Consideraciones de Seguridad**

- Ejecutar el script con el usuario mínimo necesario
- No almacenar credenciales en el script
- Revisar logs regularmente por actividad inusual
- Mantener backups de configuraciones críticas

### 📈 **Monitoreo Continuo**

```bash
# Crear un dashboard de estado
./check_crds-argocd.sh | grep -E "(Compatible|Incompatible|Compatible completo)" > status-summary.txt

# Integrar con sistemas de monitoreo existentes
# Ejemplo para Prometheus/Grafana
./check_crds-argocd.sh | grep "Compatible completo" | wc -l > /var/lib/node_exporter/textfile_collector/argo_compatible_crds.prom
```

## 🤝 Contribuir

### Reportar Problemas
- Usar GitHub Issues con template completo
- Incluir output completo del script
- Especificar versiones de todas las herramientas
- Describir el entorno EKS (versión K8s, región, etc.)

### Contribuir Código
1. Fork del repositorio
2. Crear branch para la feature: `git checkout -b feature/nueva-funcionalidad`
3. Commit con mensajes descriptivos
4. Push al branch: `git push origin feature/nueva-funcionalidad`
5. Crear Pull Request

### Mejoras Sugeridas
- [ ] Soporte para otros proveedores cloud (GKE, AKS)
- [ ] Integración con sistemas de CI/CD
- [ ] Modo JSON para automatización
- [ ] Soporte para Argo Workflows
- [ ] Dashboard web opcional

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para detalles.

## 📞 Soporte

- **Issues**: [GitHub Issues](enlace-a-issues)
- **Discusiones**: [GitHub Discussions](enlace-a-discussions)
- **Wiki**: [Documentación Extendida](enlace-a-wiki)

---

**⚡ Tip**: Ejecuta este script antes de cada actualización de Argo CD para evitar problemas de compatibilidad y asegurar un proceso de actualización sin interrupciones.

**🎯 Objetivo**: Mantener tus CRDs de Argo CD siempre actualizados y compatibles con tu versión de aplicación en EKS, garantizando la estabilidad y disponibilidad de tu plataforma GitOps.