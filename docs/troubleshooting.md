# Troubleshooting

Guía completa para solucionar problemas comunes con ArgoCD Solutions Manager.

## 🚨 Problemas Comunes

### 1. Error: "Dependencias Faltantes"

#### Síntoma
```bash
❌ kubectl falta
❌ helm falta  
❌ python3-tk falta
```

#### Solución
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y kubectl helm python3-tk git jq

# macOS
brew install kubectl helm python-tk git jq

# CentOS/RHEL
sudo yum install -y python3-tkinter git jq
# Instalar kubectl y helm manualmente
```

#### Verificación
```bash
kubectl version --client
helm version
python3 -c "import tkinter"
```

### 2. Error: "No se puede conectar a Kubernetes"

#### Síntoma
```bash
Error: Unable to connect to the server: dial tcp: lookup kubernetes.docker.internal
```

#### Diagnóstico
```bash
# Verificar contexto actual
kubectl config current-context

# Verificar conectividad
kubectl cluster-info

# Verificar configuración
kubectl config view
```

#### Solución
```bash
# Configurar contexto correcto
kubectl config use-context <your-context>

# Si usas minikube
minikube start
kubectl config use-context minikube

# Para clusters remotos
kubectl config set-cluster <cluster-name> --server=<server-url>
kubectl config set-context <context-name> --cluster=<cluster-name>
```

### 3. Error: "Namespace 'argocd' no encontrado"

#### Síntoma
```bash
Error: namespaces "argocd" not found
```

#### Diagnóstico
```bash
# Listar namespaces disponibles
kubectl get namespaces | grep -i argo

# Verificar instalación de ArgoCD
kubectl get deployments -A | grep -i argo
```

#### Solución
```bash
# Si ArgoCD está en otro namespace
export ARGOCD_NAMESPACE=<your-argocd-namespace>

# Si ArgoCD no está instalado
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configurar herramientas para usar namespace correcto
./script.sh --namespace <your-argocd-namespace>
```

### 4. Error: "Permisos insuficientes"

#### Síntoma
```bash
Error: applications.argoproj.io is forbidden: User "system:serviceaccount:default:default" cannot list applications
```

#### Diagnóstico
```bash
# Verificar usuario actual
kubectl auth whoami

# Verificar permisos
kubectl auth can-i list applications.argoproj.io -n argocd
kubectl auth can-i get pods -n argocd
```

#### Solución
```bash
# Crear ClusterRole con permisos necesarios
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-tools-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["argoproj.io"]
  resources: ["applications", "appprojects"]
  verbs: ["get", "list", "watch", "patch", "update"]
EOF

# Bind a tu usuario
kubectl create clusterrolebinding argocd-tools-binding \
  --clusterrole=argocd-tools-reader \
  --user=$(kubectl auth whoami | cut -d: -f4)
```

## 🔧 Problemas Específicos por Herramienta

### Redis HA Fix

#### Problema: Redis pods no responden
```bash
# Diagnóstico
kubectl get pods -n argocd | grep redis
kubectl describe pods -n argocd -l app.kubernetes.io/name=argocd-redis-ha

# Verificar logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-redis-ha-server --tail=100
```

#### Solución
```bash
# Restart Redis HA
kubectl rollout restart statefulset/argocd-redis-ha-server -n argocd

# Si hay problemas de PVC
kubectl get pvc -n argocd | grep redis
kubectl describe pvc <redis-pvc-name> -n argocd

# Verificar Redis connectivity
kubectl exec -it argocd-redis-ha-server-0 -n argocd -- redis-cli ping
```

#### Problema: Error de autenticación Redis
```bash
# Verificar Redis auth secret
kubectl get secret argocd-redis -n argocd -o yaml

# Regenerar auth si es necesario
kubectl delete secret argocd-redis -n argocd
kubectl rollout restart statefulset/argocd-redis-ha-server -n argocd
```

### Zombie Cleaner

#### Problema: AppProjects no se eliminan
```bash
# Verificar finalizers
kubectl get appproject <project-name> -n argocd -o yaml | grep finalizers

# Verificar aplicaciones dependientes
kubectl get applications -n argocd | grep <project-name>
```

#### Solución
```bash
# Eliminar aplicaciones primero
kubectl delete application <app-name> -n argocd

# Remover finalizers manualmente (último recurso)
kubectl patch appproject <project-name> -n argocd \
  --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

# Usar force delete si es necesario
kubectl delete appproject <project-name> -n argocd --force --grace-period=0
```

### CRDs Checker

#### Problema: Error al acceder a GitHub API
```bash
# Síntoma
Error: API rate limit exceeded
```

#### Solución
```bash
# Usar token de GitHub (opcional)
export GITHUB_TOKEN=<your-github-token>

# Usar cache local
./check_crds-argocd.sh --use-cache

# Verificar manualmente
curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest
```

#### Problema: CRDs no encontrados
```bash
# Verificar CRDs instalados
kubectl get crd | grep argoproj

# Verificar versiones
kubectl get crd applications.argoproj.io -o yaml | grep version
```

### Safe CRD Upgrade

#### Problema: Error durante actualización
```bash
# Verificar backup
ls -la crd_backups/

# Restaurar desde backup
./safe_crd_upgrade_tui.sh --restore backup_<timestamp>

# Verificar estado después de restaurar
kubectl get applications -n argocd
```

#### Problema: Interfaz TUI no funciona
```bash
# Verificar dependencias TUI
python3 -c "import rich, questionary"

# Instalar dependencias si faltan
pip3 install rich questionary

# Usar modo no interactivo
./safe_crd_upgrade_tui.sh --version v2.11.3 --no-interaction
```

### Performance Monitor

#### Problema: Métricas no disponibles
```bash
# Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# Instalar metrics-server si falta
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### Problema: Alto uso de CPU en monitoreo
```bash
# Reducir frecuencia de muestreo
./performance_monitor.sh --interval 60 --duration 10

# Limitar componentes monitoreados
./performance_monitor.sh --components server,controller
```

### Security Analyzer

#### Problema: Análisis incompleto
```bash
# Verificar permisos para secrets
kubectl auth can-i get secrets -n argocd

# Verificar acceso a configuración
kubectl auth can-i get configmaps -n argocd
```

#### Problema: Score de seguridad bajo
```bash
# Identificar issues críticos
./security_analyzer.sh --category all --verbose

# Aplicar fixes automáticos
./security_analyzer.sh --auto-fix --category secrets

# Revisar recomendaciones específicas
./security_analyzer.sh --export-json | jq '.recommendations'
```

## 🐛 Problemas de la GUI

### Error: "tkinter no disponible"

#### Síntoma
```bash
ModuleNotFoundError: No module named '_tkinter'
```

#### Solución
```bash
# Ubuntu/Debian
sudo apt install python3-tk

# CentOS/RHEL
sudo yum install tkinter

# macOS
brew install python-tk

# Para entornos virtuales
pip install tk
```

### GUI no se abre o se cierra inmediatamente

#### Diagnóstico
```bash
# Verificar DISPLAY (en Linux/macOS)
echo $DISPLAY

# Probar GUI simple
python3 -c "import tkinter; tkinter.Tk().mainloop()"
```

#### Solución
```bash
# Para SSH/WSL
export DISPLAY=:0
# o usar X11 forwarding
ssh -X user@server

# Para Docker
docker run -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix app

# Para macOS, instalar XQuartz si es necesario
```

### Error: "No se puede ejecutar script"

#### Síntoma
```bash
./script.sh: Permission denied
```

#### Solución
```bash
# Hacer ejecutables todos los scripts
find . -name "*.sh" -exec chmod +x {} \;

# Verificar permisos
ls -la *.sh

# Ejecutar con Python explícitamente
python3 argocd_manager_gui.py
```

## 🔍 Debugging Avanzado

### Habilitar Modo Debug

#### Variables de Entorno
```bash
# Habilitar debug en todas las herramientas
export DEBUG=true
export VERBOSE=true

# Debug específico por herramienta
export REDIS_DEBUG=true
export CRD_DEBUG=true
export SECURITY_DEBUG=true
```

#### Logs Detallados
```bash
# Ejecutar con logs detallados
./script.sh --verbose --debug 2>&1 | tee debug.log

# Analizar logs
grep -i error debug.log
grep -i warning debug.log
```

### Análisis de Rendimiento

#### Profiling de Scripts
```bash
# Medir tiempo de ejecución
time ./script.sh

# Profiling detallado con strace
strace -c ./script.sh

# Monitoreo de recursos
top -p $(pgrep -f script.sh)
```

### Troubleshooting de Red

#### Conectividad Kubernetes
```bash
# Test básico de conectividad
kubectl cluster-info dump

# Test de DNS
nslookup kubernetes.default.svc.cluster.local

# Test de certificados
openssl s_client -connect <k8s-api-server>:6443
```

#### Problemas de Proxy
```bash
# Verificar configuración de proxy
echo $HTTP_PROXY
echo $HTTPS_PROXY
echo $NO_PROXY

# Configurar para Kubernetes
export NO_PROXY=localhost,127.0.0.1,kubernetes.docker.internal
```

## 📋 Checklist de Troubleshooting

### Antes de Reportar un Issue

1. **Información del Sistema**
```bash
# Recopilar información del sistema
echo "OS: $(uname -a)"
echo "Python: $(python3 --version)"
echo "Kubectl: $(kubectl version --client --short)"
echo "Helm: $(helm version --short)"
echo "Context: $(kubectl config current-context)"
```

2. **Estado de ArgoCD**
```bash
# Verificar estado de ArgoCD
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

3. **Logs Relevantes**
```bash
# Recopilar logs de la última ejecución
./script.sh --verbose > output.log 2>&1

# Logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100
```

4. **Configuración**
```bash
# Exportar configuración (sin secretos)
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml
kubectl get configmap argocd-cm -n argocd -o yaml
```

### Información para Issues

Al reportar un problema, incluye:
- Versión de las herramientas
- Sistema operativo
- Versión de Kubernetes
- Versión de ArgoCD
- Comando ejecutado
- Output completo del error
- Logs relevantes

## 🆘 Contacto de Soporte

### Escalación de Problemas

#### Nivel 1: Self-service
- Revisar esta guía de troubleshooting
- Verificar documentación específica de cada herramienta
- Buscar en issues conocidos del repositorio

#### Nivel 2: Community Support
- Crear issue en GitHub con información completa
- Consultar documentación oficial de ArgoCD
- Revisar Slack/Discord de la comunidad ArgoCD

#### Nivel 3: Enterprise Support
- Contactar equipo de DevOps de British Airways
- Email: devops@company.com
- Escalación crítica: Incluir logs completos y contexto

### Información de Contacto

**Maintainer:** Jaime Henao  
**Email:** jaime.andres.henao.arbelaez@ba.com  
**GitHub:** [@Portfolio-jaime](https://github.com/Portfolio-jaime)  
**Organización:** British Airways DevOps Team

### Contribuciones

Si encuentras un problema y lo solucionas:
1. Documenta la solución
2. Crea un PR con la corrección
3. Actualiza esta guía de troubleshooting
4. Comparte con la comunidad

---

**💡 Tip:** Siempre ejecuta las herramientas con `--dry-run` primero en entornos de producción para verificar qué acciones se realizarán.