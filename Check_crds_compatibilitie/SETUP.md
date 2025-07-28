# ⚙️ Setup

Guía para instalar las herramientas necesarias:

## 1. `kubectl`
Gestión de Kubernetes.
- [Documentación oficial](https://kubernetes.io/docs/tasks/tools/)

## 2. `git`
Clonar el repo de ArgoCD.
- macOS: `brew install git`
- Linux: `sudo apt install git`

## 3. `yq`
Procesar YAML en Bash.
- [GitHub](https://github.com/mikefarah/yq)
- macOS: `brew install yq`
- Linux: `snap install yq`

## 4. `gum`
Menús y prompts interactivos.
- [GitHub](https://github.com/charmbracelet/gum)
- macOS: `brew install charmbracelet/tap/gum`
- Linux: `sudo apt install gum`
- Alternativa: `go install github.com/charmbracelet/gum@latest`

---

## ✅ Verificación

```bash
kubectl version --client
git --version
yq --version
gum --version
```