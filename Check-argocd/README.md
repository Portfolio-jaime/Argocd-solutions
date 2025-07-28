# 🧹 ArgoCD Zombie Cleaner (Python + TUI)

Herramienta interactiva en Python que detecta y elimina `AppProjects` atascados en ArgoCD con finalizers (`resources-finalizer.argocd.argoproj.io`) pero sin aplicaciones activas.

Ideal para mantener tu clúster limpio y evitar recursos zombis que impiden despliegues futuros.

---

## 🚀 Características

- Descubre AppProjects con `deletionTimestamp` + finalizer.
- Verifica que no tengan `Applications` activas.
- Confirmación interactiva por cada eliminación.
- UI TUI amigable (con `rich` y `questionary`).
- Logs con timestamp por cada acción realizada.

---

## 📦 Requisitos

- Python 3.8+
- `kubectl` configurado (con acceso al namespace `argocd`)
- Dependencias de Python:
  ```bash
  pip install rich questionary

🧪 Uso

python argocd_zombie_cleaner.py

📝 Ejemplo de ejecución

🔍 Buscando AppProjects zombis en ArgoCD...

┏━━━┳━━━━━━━━━━━━━━━━━━━━━━━┓
┃ # ┃ Nombre del Proyecto   ┃
┣━━━╋━━━━━━━━━━━━━━━━━━━━━━━┫
┃ 1 ┃ al-project            ┃
┃ 2 ┃ bff-project           ┃
┗━━━┻━━━━━━━━━━━━━━━━━━━━━━━┛

🧪 Verificando aplicaciones activas para: al-project
❓ ¿Eliminar finalizer de 'al-project'? [Y/n]

✅ Finalizer eliminado de: al-project

📂 Logs

Los logs se almacenan automáticamente en la carpeta logs/ con nombre:

bash
Copy
Edit
zombie_cleaner_YYYYMMDD_HHMMSS.log
Ejemplo:

csharp
Copy
Edit
2025-07-22 15:45:10 - Removed finalizer from al-project
🛡️ Seguridad
La herramienta no elimina nada sin confirmación.

Verifica que no haya aplicaciones activas antes de eliminar finalizers.

Úsala con confianza en ambientes de staging, dev o incluso producción (tras validaciones).

🧑‍💻 Autor
Jaime Andres Henao
