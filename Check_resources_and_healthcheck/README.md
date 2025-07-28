# 🔎 ArgoCD Inspector

Este script audita de forma segura tu instalación de ArgoCD desplegada vía Helm, sin modificar nada en el clúster.

## 🚀 ¿Qué hace?

- Verifica si el release de ArgoCD está presente
- Extrae valores de configuración (`server.url`, `dex.config`, `policy.csv`)
- Evalúa la configuración de `livenessProbe` y `readinessProbe`
- Identifica parámetros problemáticos con advertencias (`⚠️`)
- Analiza el uso actual de recursos (CPU/Memory)
- Exporta todo el reporte a un archivo Markdown (`argocd_inspection_report.md`)

## 🛡 Seguridad

> Este script **no aplica ningún cambio**. Solo ejecuta comandos de lectura (`helm get`, `kubectl get`, `jq`, `yq`).

## 📦 Requisitos

### Herramientas necesarias:

```bash
# macOS
brew install helm kubernetes-cli jq yq

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq
sudo snap install helm --classic
sudo snap install kubectl --classic
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq

# CentOS/RHEL
sudo yum install -y jq
# Instalar helm y kubectl manualmente desde sus releases oficiales
```

### Acceso al clúster:
- Contexto de kubectl configurado
- Permisos de lectura en el namespace de ArgoCD

## ⚙️ Uso

### Uso básico:
```bash
chmod +x inspect_argocd.sh
./inspect_argocd.sh
```

### Uso avanzado:
```bash
# Especificar namespace y release personalizados
./inspect_argocd.sh my-argocd-release my-argocd-namespace

# Especificar archivo de salida personalizado
./inspect_argocd.sh argocd argocd custom-report.md
```

### Parámetros:
- `$1`: Nombre del release Helm (default: `argocd`)
- `$2`: Namespace (default: `argocd`)  
- `$3`: Archivo de salida (default: `argocd_inspection_report.md`)

Se generará el reporte especificado con todos los resultados.

## 📋 Contenido del reporte

El script genera un reporte completo que incluye:

### ✅ Configuraciones del Helm release
- **🌐 URL configurada**: Endpoint público de ArgoCD
- **🔐 Dex.config**: Configuración de SSO (GitHub, etc.)
- **🔒 policy.csv**: Políticas RBAC definidas

### 🚑 Health Checks por pod
Para cada pod de ArgoCD se analiza:
- **LivenessProbe**: Configuración de detección de fallos
- **ReadinessProbe**: Configuración de disponibilidad
- **Estado del pod**: Running, Pending, Failed, etc.

### 📊 Recursos actuales
- Uso de CPU y memoria por pod (si metrics-server está disponible)

### ⚠️ Alertas automáticas
El script detecta configuraciones problemáticas y las marca con alertas.

## 📌 Umbrales recomendados para Probes

| Parámetro | Valor recomendado | Justificación |
|-----------|-------------------|---------------|
| `initialDelaySeconds` | ≤ 30 | Evitar latencia innecesaria |
| `periodSeconds` | ≤ 15 | Mayor frecuencia de chequeo |
| `failureThreshold` | ≤ 5 | Menor tolerancia a errores |
| `timeoutSeconds` | ≤ 5 | Respuesta rápida esperada |

## 📝 Ejemplo de salida

```bash
$ ./inspect_argocd.sh
🔎 Iniciando inspección de ArgoCD...
   Namespace: argocd
   Release: argocd
   Output: argocd_inspection_report.md

## 📦 Verificando release Helm...
✅ Release encontrado

✅ Reporte generado: argocd_inspection_report.md
📄 Para ver el reporte: cat argocd_inspection_report.md
```

## 🔧 Troubleshooting

### Error: "Missing required dependencies"
```bash
# Verificar herramientas instaladas
which kubectl helm jq yq

# Instalar las faltantes según tu OS
```

### Error: "Release 'argocd' no encontrado"
```bash
# Listar releases disponibles
helm list -A

# Usar el nombre correcto
./inspect_argocd.sh <release-name> <namespace>
```

### Error: "Namespace 'argocd' no existe"
```bash
# Verificar namespaces disponibles
kubectl get namespaces

# Especificar el namespace correcto
./inspect_argocd.sh argocd <existing-namespace>
```

## 🧠 Extensiones sugeridas

- [ ] Agregar soporte para múltiples entornos (dev, sit, prod) 
- [ ] Exportar como JSON para dashboards
- [ ] Integrar con herramientas de monitoreo (Prometheus/AlertManager)
- [ ] Añadir análisis de logs de pods con errores
- [ ] Verificación de certificados TLS

## ✍ Autor

**Jaime Andrés Henao**  
Cloud Engineer / DevOps | Inspeccionando sin miedo™ 😎