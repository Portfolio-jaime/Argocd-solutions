# ArgoCD Solutions Manager

Una solución completa con interfaz gráfica para gestionar y ejecutar todas las herramientas de diagnóstico, mantenimiento y actualización de ArgoCD.

## 📋 Descripción

Este proyecto integra múltiples herramientas especializadas para ArgoCD en una interfaz gráfica única y fácil de usar. Permite ejecutar scripts de diagnóstico, limpieza, actualización y mantenimiento desde una sola aplicación.

## 🚀 Inicio Rápido

### Requisitos Previos
- Python 3.8+
- kubectl configurado
- Acceso al cluster de Kubernetes con ArgoCD

### Instalación
```bash
git clone https://github.com/Portfolio-jaime/Argocd-solutions.git
cd Argocd-solutions
pip install -r requirements.txt
```

### Ejecución
```bash
# Interfaz gráfica moderna
python argocd_manager_modern_gui.py

# Interfaz gráfica clásica
python argocd_manager_gui.py
```

## 🛠️ Herramientas Disponibles

| Categoría | Herramienta | Descripción |
|-----------|-------------|-------------|
| **Mantenimiento** | Redis HA Fix | Diagnostica y repara problemas de Redis HA |
| **Mantenimiento** | Zombie Cleaner | Limpia AppProjects con finalizers atorados |
| **Validación** | CRDs Checker | Verifica compatibilidad de Custom Resource Definitions |
| **Validación** | ArgoCD Inspector | Inspecciona configuración y estado |
| **Actualización** | CRD Updater | Actualiza CRDs de ArgoCD de forma segura |
| **Performance** | Performance Monitor | Monitorea rendimiento y genera reportes |
| **Seguridad** | Security Analyzer | Analiza configuración de seguridad |

## 📊 Características

- **Interfaz Gráfica Intuitiva**: UI moderna con tkinter
- **Ejecución Segura**: Validaciones previas antes de ejecutar scripts
- **Logs Detallados**: Seguimiento completo de todas las operaciones
- **Reportes**: Generación automática de reportes de performance y seguridad
- **Backup Automático**: Respaldo de configuraciones antes de cambios críticos

## 🎯 Casos de Uso

### Mantenimiento Rutinario
- Limpieza de recursos huérfanos
- Verificación de estado de Redis HA
- Monitoreo de performance

### Actualizaciones
- Validación pre-actualización
- Actualización segura de CRDs
- Verificación post-actualización

### Troubleshooting
- Diagnóstico de problemas de sincronización
- Análisis de recursos problemáticos
- Inspección de configuración

## 📈 Arquitectura

El proyecto está organizado en módulos especializados:

```
Argocd-solutions/
├── GUI/                    # Interfaces gráficas
├── Check-*/               # Herramientas de validación
├── Performance_monitor/   # Monitoreo de rendimiento
├── Security_analyzer/     # Análisis de seguridad
├── Update_*/             # Herramientas de actualización
└── requirements.txt      # Dependencias Python
```

## 🔗 Enlaces Útiles

- [Guía de Mantenimiento](maintenance.md)
- [Herramientas de Validación](validation.md)
- [Proceso de Actualización](updates.md)
- [Monitoreo de Performance](performance.md)
- [Análisis de Seguridad](security.md)
- [Troubleshooting](troubleshooting.md)

## 📞 Soporte

Para soporte técnico o reportar issues, contacta al equipo de DevOps de British Airways.

**Autor:** Jaime Henao <jaime.andres.henao.arbelaez@ba.com>  
**Organización:** British Airways DevOps Team