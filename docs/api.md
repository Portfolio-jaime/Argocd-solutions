# API Reference

Referencia completa de APIs y interfaces de las herramientas ArgoCD Solutions.

## 🚀 GUI APIs

### Interfaz Gráfica Moderna
```python
# Ejecutar GUI moderna
python3 argocd_manager_modern_gui.py

# Parámetros disponibles
python3 argocd_manager_modern_gui.py --help
```

#### Métodos de la GUI
```python
class ArgoCDManagerModern:
    def __init__(self):
        """Inicializa la interfaz moderna"""
        
    def create_tool_card(self, tool_name, description, category):
        """Crea tarjeta de herramienta
        Args:
            tool_name (str): Nombre de la herramienta
            description (str): Descripción detallada
            category (str): Categoría (maintenance, validation, etc.)
        """
        
    def execute_tool(self, tool_script, background=True):
        """Ejecuta herramienta en background
        Args:
            tool_script (str): Ruta al script
            background (bool): Ejecutar en background
        Returns:
            subprocess.Popen: Proceso en ejecución
        """
        
    def update_dashboard_metrics(self):
        """Actualiza métricas en tiempo real del dashboard"""
        
    def export_logs(self, format='txt'):
        """Exporta logs de ejecución
        Args:
            format (str): Formato de exportación (txt, json, csv)
        """
```

## 🛠️ CLI Tool APIs

### Redis HA Fix
```bash
# API del script Redis HA Fix
./Check-Redis-ha/redis-ha-fix.sh [OPTIONS]

Options:
  --diagnose        Solo ejecutar diagnóstico
  --fix            Aplicar correcciones automáticas
  --namespace      Namespace de ArgoCD (default: argocd)
  --verbose        Salida detallada
  --dry-run        Simular sin aplicar cambios
  --timeout        Timeout en segundos (default: 300)

Exit Codes:
  0    Éxito
  1    Error general
  2    No se pudo conectar a Kubernetes
  3    Namespace no encontrado
  4    Redis HA no encontrado
```

#### Ejemplo de Uso
```bash
# Diagnóstico completo
./redis-ha-fix.sh --diagnose --verbose

# Aplicar correcciones
./redis-ha-fix.sh --fix --namespace production-argocd

# Modo dry-run
./redis-ha-fix.sh --diagnose --dry-run
```

### Zombie Cleaner
```bash
# API del Zombie Cleaner
./Check-argocd/argocd-zombie-cleaner.sh [OPTIONS]

Options:
  --list           Listar recursos zombie sin eliminar
  --clean          Limpiar recursos zombie
  --namespace      Namespace específico (default: all)
  --dry-run        Mostrar qué se eliminaría
  --force          Eliminar sin confirmación
  --backup         Crear backup antes de eliminar
  --auto-confirm   Confirmar automáticamente eliminaciones

Exit Codes:
  0    Éxito - No hay recursos zombie o limpieza exitosa
  1    Error de conexión o permisos
  2    Recursos zombie encontrados (con --list)
  3    Error durante limpieza
```

#### Ejemplo de Uso
```bash
# Listar recursos zombie
./argocd-zombie-cleaner.sh --list

# Limpiar con backup
./argocd-zombie-cleaner.sh --clean --backup --namespace argocd

# Limpieza forzada (cuidado!)
./argocd-zombie-cleaner.sh --clean --force --auto-confirm
```

### CRDs Checker
```bash
# API del CRDs Checker
./Check_CRDs-K8s/check_crds-argocd.sh [OPTIONS]

Options:
  --target-version VERSION    Versión objetivo de ArgoCD
  --current-only             Solo mostrar versión actual
  --compare VERSION          Comparar con versión específica
  --include-rollouts         Incluir Argo Rollouts en análisis
  --export-report FORMAT     Exportar reporte (json, yaml, txt)
  --verbose                  Salida detallada

Exit Codes:
  0    Compatible - Seguro actualizar
  1    Error de análisis
  2    Incompatibilidad detectada
  3    Actualización no recomendada
```

### Safe CRD Upgrade
```bash
# API del Safe CRD Upgrade
./Check_crds_compatibilitie/safe_crd_upgrade_tui.sh [OPTIONS]

Options:
  --version VERSION      Versión específica (salta menú TUI)
  --list-versions       Lista versiones disponibles
  --backup-only         Solo crear backup
  --restore BACKUP      Restaurar desde backup específico
  --no-interaction      Modo no interactivo
  --force               Forzar actualización sin validaciones

Exit Codes:
  0    Actualización exitosa
  1    Error durante actualización
  2    Validación fallida
  3    Backup/Restore falló
  4    Usuario canceló operación
```

## 📊 Performance Monitor API

### CLI Interface
```bash
# API del Performance Monitor
./Performance_monitor/performance_monitor.sh [OPTIONS]

Options:
  --duration MINUTES         Duración del monitoreo (default: 5)
  --interval SECONDS         Intervalo entre muestras (default: 30)
  --components COMPONENTS     Componentes específicos (server,controller,repo)
  --export-csv              Exportar datos a CSV
  --export-prometheus       Formato Prometheus
  --output PATH             Directorio de salida
  --silent                  Sin salida en pantalla
  --alert-thresholds FILE   Archivo de configuración de alertas

Exit Codes:
  0    Monitoreo completado exitosamente
  1    Error de configuración
  2    Error de conectividad K8s
  3    Alertas críticas detectadas
```

### Métricas API
```bash
# Obtener métricas específicas
./performance_monitor.sh --components server --duration 1 --export-json

# Salida JSON estructura:
{
  "timestamp": "2025-08-22T14:30:00Z",
  "duration_minutes": 1,
  "components": {
    "argocd-server": {
      "cpu_percent": 45.2,
      "memory_mb": 1234,
      "memory_percent": 61.7,
      "requests_per_second": 23.4,
      "response_time_ms": 145
    }
  },
  "alerts": [
    {
      "severity": "warning",
      "component": "argocd-server",
      "metric": "memory_percent", 
      "value": 61.7,
      "threshold": 60.0
    }
  ]
}
```

## 🔐 Security Analyzer API

### CLI Interface
```bash
# API del Security Analyzer
./Security_analyzer/security_analyzer.sh [OPTIONS]

Options:
  --category CATEGORY        Categoría específica de análisis
  --compliance FRAMEWORK     Framework de compliance (soc2, iso27001)
  --export-json             Exportar reporte en JSON
  --export-html             Generar reporte HTML
  --silent                  Modo silencioso para CI/CD
  --exit-code               Exit code basado en security score
  --auto-fix                Aplicar correcciones automáticas
  --baseline FILE           Comparar con baseline de seguridad

Categories:
  authentication    Análisis de autenticación y SSO
  authorization     RBAC y políticas de autorización  
  network           Seguridad de red y TLS
  secrets           Gestión y análisis de secretos
  compliance        Verificación de compliance
  all              Análisis completo (default)

Exit Codes:
  0    Security score >= 80 (Good)
  1    Security score 60-79 (Fair) 
  2    Security score < 60 (Poor)
  3    Error durante análisis
```

### JSON Output Schema
```json
{
  "security_analysis": {
    "timestamp": "2025-08-22T14:30:00Z",
    "overall_score": 76,
    "grade": "Good",
    "categories": {
      "authentication": {
        "score": 85,
        "status": "good",
        "issues": [
          {
            "severity": "medium",
            "title": "Session timeout too long",
            "description": "Current session timeout is 24h, recommend 8h",
            "remediation": "Update session timeout in dex configuration"
          }
        ]
      }
    },
    "compliance": {
      "soc2": {
        "score": 72,
        "status": "needs_improvement",
        "missing_controls": ["CC6.1", "CC6.3"]
      }
    },
    "recommendations": [
      {
        "priority": "high",
        "category": "secrets",
        "action": "Enable encryption at rest",
        "impact": "Improves data protection compliance"
      }
    ]
  }
}
```

## 🕵️ Orphan Analyzer API

### CLI Interface
```bash
# API del Orphan Analyzer
./Orphan_resources_analyzer/orphan_analyzer.sh [OPTIONS]

Options:
  --namespace NAMESPACE      Namespace específico (default: all)
  --resource-type TYPE       Tipo de recurso específico
  --risk-level LEVEL         Filtrar por nivel de riesgo (safe, moderate, risky)
  --export-cleanup-script    Generar script de limpieza
  --dry-run                  Solo análisis, no generar scripts
  --exclude-system           Excluir recursos del sistema
  --output-format FORMAT     Formato de salida (table, json, csv)

Resource Types:
  deployments, services, configmaps, secrets, ingresses,
  persistentvolumeclaims, jobs, cronjobs, all

Risk Levels:
  safe       Recursos seguros para eliminar
  moderate   Requieren revisión manual
  risky      No recomendado eliminar automáticamente

Exit Codes:
  0    Análisis completado, no hay recursos huérfanos
  1    Error durante análisis
  2    Recursos huérfanos encontrados
  3    Recursos de alto riesgo detectados
```

## 🔧 Inspector API

### CLI Interface
```bash
# API del ArgoCD Inspector
./Check_resources_and_healthcheck/inspect_argocd.sh [OPTIONS]

Options:
  --config-only             Solo análisis de configuración
  --resources-only          Solo análisis de recursos
  --include-apps            Incluir análisis de aplicaciones
  --export-markdown         Exportar reporte a Markdown
  --export-json             Exportar reporte a JSON
  --webhook URL             Enviar reporte a webhook
  --namespace NAMESPACE     Namespace de ArgoCD

Exit Codes:
  0    Inspección completada - Sistema saludable
  1    Advertencias detectadas
  2    Problemas críticos encontrados
  3    Error durante inspección
```

## 📋 Pre-update Validation API

### CLI Interface  
```bash
# API del Pre-update Check
./Pre-update_check/pre-validation.sh [OPTIONS]

Options:
  --quick                   Validación rápida (checks básicos)
  --redis-only             Solo validar Redis HA
  --include-apps            Incluir validación de aplicaciones
  --skip-resources         Saltar validación de recursos
  --export-report          Exportar reporte de validación
  --fail-fast              Terminar en primera falla

Validation Categories:
  - System health (pods, services)
  - Redis HA connectivity  
  - Application sync status
  - Resource utilization
  - Network connectivity
  - Configuration validation

Exit Codes:
  0    Todas las validaciones pasaron
  1    Advertencias encontradas (seguro continuar)
  2    Validaciones críticas fallaron
  3    Error durante validación
```

## 🔗 Integration APIs

### Webhook Integration
```bash
# Configurar webhooks para notificaciones
export SLACK_WEBHOOK="https://hooks.slack.com/services/..."
export TEAMS_WEBHOOK="https://company.webhook.office.com/..."

# Todas las herramientas soportan webhooks
./any_tool.sh --webhook $SLACK_WEBHOOK
```

### Prometheus Integration
```bash
# Exportar métricas para Prometheus
./performance_monitor.sh --export-prometheus > argocd_metrics.prom

# Metrics disponibles:
# argocd_cpu_usage_percent{component="server"}
# argocd_memory_usage_mb{component="controller"}  
# argocd_response_time_ms{endpoint="/api/v1/applications"}
# argocd_sync_duration_seconds{application="frontend"}
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: ArgoCD Security Check
  run: |
    ./Security_analyzer/security_analyzer.sh --silent --exit-code
    if [ $? -eq 2 ]; then
      echo "Security score too low, blocking deployment"
      exit 1
    fi

- name: Pre-deployment Validation
  run: |
    ./Pre-update_check/pre-validation.sh --quick --export-report
    # Upload validation report as artifact
```

## 📊 Monitoring Integration

### Grafana Dashboard API
```bash
# Exportar métricas para Grafana
./performance_monitor.sh --duration 60 --export-json > metrics.json

# Estructura compatible con Grafana:
{
  "dashboard": "ArgoCD Performance",
  "panels": [
    {
      "title": "CPU Usage",
      "targets": [
        {
          "expr": "argocd_cpu_usage_percent",
          "legendFormat": "{{component}}"
        }
      ]
    }
  ]
}
```

### SIEM Integration
```bash
# Exportar logs de seguridad para SIEM
./security_analyzer.sh --export-json --siem-format

# Output compatible con Splunk, ELK, etc.
{
  "event_type": "security_analysis",
  "timestamp": "2025-08-22T14:30:00Z",
  "source": "argocd_security_analyzer", 
  "severity": "medium",
  "category": "authentication",
  "message": "Weak session timeout detected",
  "metadata": {
    "current_timeout": "24h",
    "recommended_timeout": "8h"
  }
}
```

## 📞 API Support

### Error Handling
Todas las herramientas siguen el mismo patrón de manejo de errores:
- Exit codes estándar (0=success, 1+=error)
- Logs estructurados con timestamps
- Mensajes de error descriptivos
- Códigos de error específicos por herramienta

### Rate Limiting
- Llamadas a Kubernetes API: Respeta los rate limits del cluster
- Operaciones concurrentes: Limitadas por defecto
- Timeouts configurables: Para operaciones de larga duración

### Authentication
- Usa kubeconfig del usuario actual
- Respeta RBAC policies de Kubernetes
- No requiere credenciales adicionales
- Soporte para service accounts