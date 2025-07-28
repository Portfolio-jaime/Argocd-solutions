# ArgoCD CRDs Compatibility Checker

<div align="center">

![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS EKS](https://img.shields.io/badge/AWS_EKS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)

**Una herramienta profesional para verificar la compatibilidad de CRDs de ArgoCD en clusters EKS**

[Características](#-características) •
[Instalación](#-instalación) •
[Uso](#-uso) •
[Ejemplos](#-ejemplos) •
[Troubleshooting](#-troubleshooting)

</div>

## 📋 Descripción

El **ArgoCD CRDs Compatibility Checker** es una herramienta avanzada diseñada específicamente para administradores de clusters EKS que necesitan verificar y mantener la compatibilidad de los Custom Resource Definitions (CRDs) de ArgoCD.

### 🎯 Propósito

- **Prevenir fallos**: Identifica incompatibilidades antes de que causen problemas
- **Facilitar actualizaciones**: Proporciona planes de actualización paso a paso
- **Automatizar verificaciones**: Integrable en pipelines CI/CD
- **Generar reportes**: Múltiples formatos de salida para diferentes audiencias

## ✨ Características

### 🔍 Análisis Completo
- ✅ **Detección automática** de cluster EKS y contexto Kubernetes
- ✅ **Análisis detallado** de CRDs de ArgoCD (applications, applicationsets, appprojects)
- ✅ **Verificación de versiones** API y compatibilidad cross-version
- ✅ **Identificación de problemas** con recomendaciones específicas

### 📊 Múltiples Formatos de Salida
- 🎨 **Tabla** - Formato visual elegante con colores e iconos
- 📄 **JSON** - Perfecto para APIs e integración con herramientas
- 📈 **CSV** - Ideal para análisis de datos y reportes

### 🛠️ Opciones Avanzadas
- 🔄 **Dry-run mode** - Simulación sin ejecución real
- 📝 **Logging detallado** - Para auditoría y troubleshooting
- ⏱️ **Timeouts configurables** - Adaptable a diferentes entornos
- 🔧 **Namespaces personalizados** - Soporte completo para configuraciones custom

### 🚀 Integración
- ✅ Compatible con **Bash 3.0+** (macOS, Linux, Unix)
- ✅ Integrable en **CI/CD pipelines**
- ✅ Soporte para **automatización** y **scripting**
- ✅ **Códigos de salida específicos** para control de flujo

## 📦 Instalación

### Prerrequisitos

| Herramienta | Versión | Requerido | Descripción |
|-------------|---------|-----------|-------------|
| `kubectl` | 1.20+ | ✅ **Obligatorio** | Cliente de Kubernetes |
| `bash` | 3.0+ | ✅ **Obligatorio** | Shell de ejecución |
| `helm` | 3.0+ | 🔶 Opcional | Para información de releases |
| `jq` | 1.6+ | 🔶 Opcional | Para parsing JSON mejorado |
| `aws` | 2.0+ | 🔶 Opcional | Para información EKS detallada |

### Instalación Rápida

```bash
# Clonar o descargar el script
wget https://raw.githubusercontent.com/tu-repo/argocd-crd-checker/main/check_crds_argocd.sh

# Hacer ejecutable
chmod +x check_crds_argocd.sh

# Verificar instalación
./check_crds_argocd.sh --version
```

### Verificación de Dependencias

```bash
# El script verificará automáticamente las dependencias
./check_crds_argocd.sh --dry-run
```

## 🚀 Uso

### Sintaxis Básica

```bash
./check_crds_argocd.sh [OPCIONES]
```

### Opciones Disponibles

| Opción | Descripción | Valor por Defecto |
|--------|-------------|-------------------|
| `-n, --namespace` | Namespace de ArgoCD | `argocd` |
| `-t, --timeout` | Timeout para comandos (segundos) | `30` |
| `-o, --output` | Formato de salida | `table` |
| `-e, --export` | Exportar resultados a archivo | - |
| `-l, --log` | Habilitar logging a archivo | - |
| `-v, --verbose` | Salida detallada | `false` |
| `-d, --dry-run` | Modo simulación | `false` |
| `-h, --help` | Mostrar ayuda | - |
| `--version` | Mostrar versión | - |

### Códigos de Salida

| Código | Descripción |
|--------|-------------|
| `0` | ✅ Éxito - Todo compatible |
| `1` | ❌ Argumentos inválidos |
| `2` | ❌ Dependencias faltantes |
| `3` | ❌ Error de kubectl/Kubernetes |
| `4` | ⚠️ Problemas de compatibilidad encontrados |
| `5` | ❌ Error general |

## 📋 Ejemplos

### Uso Básico

```bash
# Verificación estándar
./check_crds_argocd.sh

# Verificación con namespace personalizado
./check_crds_argocd.sh -n mi-argocd

# Verificación con output detallado
./check_crds_argocd.sh -v
```

### Formatos de Salida

```bash
# Formato tabla (predeterminado)
./check_crds_argocd.sh -o table

# Formato JSON para APIs
./check_crds_argocd.sh -o json

# Formato CSV para análisis
./check_crds_argocd.sh -o csv
```

### Exportación y Logging

```bash
# Exportar resultados JSON
./check_crds_argocd.sh -o json -e resultados.json

# Habilitar logging detallado
./check_crds_argocd.sh -l verificacion.log -v

# Modo dry-run con logging
./check_crds_argocd.sh --dry-run -l simulacion.log
```

### Integración CI/CD

```bash
#!/bin/bash
# Ejemplo para pipeline CI/CD

# Ejecutar verificación
./check_crds_argocd.sh -o json -e crd_status.json

# Verificar resultado
if [ $? -eq 0 ]; then
    echo "✅ CRDs compatibles - Continuando deployment"
elif [ $? -eq 4 ]; then
    echo "⚠️ Problemas encontrados - Revisar crd_status.json"
    exit 1
else
    echo "❌ Error en verificación"
    exit 1
fi
```

## 📊 Ejemplo de Salida

### Formato Tabla

```
════════════════════════════════════════════════════════════════════════════════
                    🔧 ANÁLISIS COMPLETO CRDs ARGO CD                    
════════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────────────┐
│                            INFORMACIÓN DEL CLUSTER                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ Cluster EKS:    │ production-cluster                                         │
│ Kubernetes:     │ v1.28.5                                                    │
│ Región AWS:     │ us-west-2                                                  │
│ Contexto:       │ arn:aws:eks:us-west-2:123456789:cluster/production        │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                              INSTALACIÓN ARGO CD                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ 📊 Helm Release:  │ argocd                                                   │
│ 🏷️ Chart Version: │ 5.51.6                                                   │
│ 🏷️ App Version:   │ v2.8.7                                                   │
│ ⚙️ Imagen:        │ quay.io/argoproj/argocd:v2.8.7                          │
│ 🏷️ Versión:       │ v2.8.7                                                   │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                      ANÁLISIS DETALLADO DE COMPATIBILIDAD                      │
├──────────────────────────────────────────────────────────────────────────────┤
│ CRD                  │ Versiones API   │ Estado               │ Fecha        │
├──────────────────────────────────────────────────────────────────────────────┤
│ applications         │ v1alpha1,v1beta1│ ✨ Compatible       │ 2024-01-15   │
│ applicationsets      │ v1alpha1        │ ✨ Compatible       │ 2024-01-15   │
│ appprojects          │ v1alpha1        │ ✨ Compatible       │ 2024-01-15   │
└──────────────────────────────────────────────────────────────────────────────┘

════════════════════════════════════════════════════════════════════════════════
                           📊 RESUMEN EJECUTIVO                           
════════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────────────┐
│                           ESTADO GENERAL DEL SISTEMA                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ ✅ ArgoCD detectado: v2.8.7                                                   │
│ ✅ Versión actual y bien soportada                                            │
│                                                                                │
│ ✅ Todos los CRDs son compatibles                                             │
│ ✅ Sistema listo para producción                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Formato JSON

```json
{
  "timestamp": "2025-07-24T14:43:45Z",
  "crds": [
    {
      "name": "applications.argoproj.io",
      "versions": "v1alpha1,v1beta1",
      "status": "OK",
      "date": "2024-01-15",
      "reason": "Soporta ambas APIs necesarias"
    },
    {
      "name": "applicationsets.argoproj.io",
      "versions": "v1alpha1",
      "status": "OK",
      "date": "2024-01-15",
      "reason": "ApplicationSets funcional"
    },
    {
      "name": "appprojects.argoproj.io",
      "versions": "v1alpha1",
      "status": "OK",
      "date": "2024-01-15",
      "reason": "Projects funcionando correctamente"
    }
  ]
}
```

## 🔧 Casos de Uso

### 1. Verificación Pre-Actualización

```bash
# Antes de actualizar ArgoCD
./check_crds_argocd.sh -v -l pre_upgrade.log

# Si encuentra problemas, seguir recomendaciones
# Si todo está OK, proceder con la actualización
```

### 2. Monitoreo Continuo

```bash
# Cron job para verificación diaria
0 9 * * * /path/to/check_crds_argocd.sh -o json -e /var/log/argocd_daily.json
```

### 3. Troubleshooting

```bash
# Cuando ArgoCD presenta problemas
./check_crds_argocd.sh -v -l troubleshoot.log
```

### 4. Auditoría y Compliance

```bash
# Generar reporte para auditoría
./check_crds_argocd.sh -o csv -e audit_$(date +%Y%m%d).csv
```

## ⚠️ Troubleshooting

### Problemas Comunes

#### Error: "Missing required dependencies"
```bash
# Verificar kubectl
kubectl version --client

# Instalar dependencias faltantes
# En macOS: brew install kubectl helm jq
# En Ubuntu: apt-get install kubectl helm jq
```

#### Error: "Namespace 'argocd' not found"
```bash
# Verificar namespaces disponibles
kubectl get namespaces

# Usar namespace correcto
./check_crds_argocd.sh -n <namespace-correcto>
```

#### Error: "kubectl command failed"
```bash
# Verificar conectividad
kubectl cluster-info

# Verificar contexto
kubectl config current-context

# Aumentar timeout si es necesario
./check_crds_argocd.sh -t 60
```

### Debugging

```bash
# Modo verbose para más información
./check_crds_argocd.sh -v -l debug.log

# Dry-run para simular sin ejecutar
./check_crds_argocd.sh --dry-run -v
```

## 🤝 Contribución

Las contribuciones son bienvenidas! Para contribuir:

1. **Fork** el repositorio
2. **Crea** una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. **Push** a la rama (`git push origin feature/AmazingFeature`)  
5. **Abre** un Pull Request

### Desarrollo Local

```bash
# Clonar repo
git clone <repo-url>
cd argocd-crd-checker

# Hacer cambios
vim check_crds_argocd.sh

# Probar cambios
./check_crds_argocd.sh --dry-run -v

# Ejecutar tests
bash tests/run_tests.sh
```

## 📝 Changelog

### v2.0.0 (2025-07-24)
- ✨ **Nueva arquitectura** refactorizada para mayor robustez
- ✨ **Múltiples formatos** de salida (tabla, JSON, CSV)
- ✨ **Compatibilidad** mejorada con Bash 3.0+
- ✨ **Sistema de caché** para comandos repetitivos
- ✨ **Logging avanzado** y modo dry-run
- ✨ **Manejo de errores** robusto con códigos específicos
- ✨ **Interfaz mejorada** con colores e iconos
- 🐛 **Correcciones** múltiples de bugs de formato
- 🔧 **Optimizaciones** de rendimiento

### v1.0.0 (2024-XX-XX)
- 🎉 Release inicial
- ✅ Verificación básica de CRDs
- ✅ Soporte para EKS

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 🙏 Reconocimientos

- **ArgoCD Team** - Por crear una herramienta increíble
- **Kubernetes Community** - Por el ecosistema de herramientas
- **AWS EKS Team** - Por facilitar Kubernetes en la nube

## 📞 Soporte

- 📧 **Email**: [tu-email@ejemplo.com]
- 🐛 **Issues**: [GitHub Issues](https://github.com/tu-repo/argocd-crd-checker/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/tu-repo/argocd-crd-checker/discussions)

---

<div align="center">

**¿Te gusta este proyecto? ¡Dale una ⭐!**

Made with ❤️ for the Kubernetes community

</div>