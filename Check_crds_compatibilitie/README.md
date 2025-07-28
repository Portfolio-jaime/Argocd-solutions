# 🔐 Safe CRD Upgrade (TUI Edition)

Herramienta interactiva para actualizar los CRDs de ArgoCD **de forma segura**:
- Backup automático
- Validación de recursos existentes
- Visualización de diferencias (diff)
- Confirmación antes de aplicar
Todo desde un menú TUI gracias a [`gum`](https://github.com/charmbracelet/gum).

---

## 🚀 Características

- Menú con las últimas 10 versiones de ArgoCD desde GitHub
- Clona automáticamente el repo de ArgoCD en la versión elegida
- Muestra los CRDs disponibles para elegir y actualizar
- Backup, validación, diff y aplicación guiada

---

## 📦 Requisitos

Necesitás estas herramientas (ver instalación en [`SETUP.md`](./SETUP.md)):

- `kubectl`
- `git`
- `yq`
- `gum`

---

## 🛠️ Uso

```bash
chmod +x safe_crd_upgrade_tui.sh
./safe_crd_upgrade_tui.sh
```

1. Elegí la versión de ArgoCD (últimas 10 tags)
2. Se clona el repo en esa versión
3. Seleccioná un CRD y se hace backup
4. Validación con recursos existentes
5. Diff vs versión actual
6. Confirmá si lo aplicás o no

---

## 📂 Estructura

```bash
./
├── safe_crd_upgrade_tui.sh
├── crd_backups/
└── tmp-argocd-<versión>/
```

---

## 💡 Recomendaciones

- Probá primero en entornos staging/dev antes de producción
- Después hacé `helm upgrade` de ArgoCD
- Guardá los backups bajo control de versiones si lo necesitás

---

## 🆕 Extensiones futuras

- Aplicar todos los CRDs en batch
- Guardar logs/historial
- Enviar alertas a Slack o Datadog

---

## 👷 Autor

Un DevOps que prefiere prevenir que curar—especialmente con CRDs 😊