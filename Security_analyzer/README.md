# 🔐 ArgoCD Security Analyzer

Herramienta comprehensiva de análisis de seguridad para instalaciones de ArgoCD. Evalúa configuraciones de autenticación, autorización, red, gestión de secretos y cumplimiento de mejores prácticas de seguridad.

## 🛡️ Características Principales

### 🔍 **Análisis Comprehensivo de Seguridad**
- ✅ **Autenticación**: SSO, OIDC, cuentas admin, políticas de contraseñas
- ✅ **Autorización**: RBAC, permisos, políticas de proyectos
- ✅ **Seguridad de Red**: Exposición de servicios, NetworkPolicies, TLS
- ✅ **Gestión de Secretos**: Credenciales, cifrado, rotación
- ✅ **Cumplimiento**: Mejores prácticas y estándares de seguridad

### 📊 **Sistema de Puntuación**
- 🎯 Score de seguridad de 0-100
- 🚨 Clasificación de issues por severidad
- 📈 Métricas detalladas por categoría
- 🎨 Reportes visuales con códigos de color

### 📋 **Reportes Detallados**
- 📄 Resumen ejecutivo con acciones prioritarias
- 🔍 Análisis detallado por categoría
- 📊 Estadísticas y métricas de seguridad
- 🎯 Recomendaciones específicas y accionables

## 🚀 Uso

### Ejecución Básica
```bash
# Análisis de seguridad completo
./security_analyzer.sh

# Namespace personalizado
./security_analyzer.sh -n argocd-production

# Solo issues de alta severidad
./security_analyzer.sh -t high
```

### Opciones Avanzadas
```bash
# Configuración completa
ARGOCD_NAMESPACE=argocd-prod \
SEVERITY_THRESHOLD=medium \
./security_analyzer.sh

# Análisis específico para compliance
./security_analyzer.sh --namespace argocd --threshold low
```

### Parámetros de Configuración
```bash
# Opciones de línea de comandos
-n, --namespace NAME        # Namespace de ArgoCD (default: argocd)
-t, --threshold LEVEL       # Umbral de severidad (low|medium|high, default: medium)  
-h, --help                  # Mostrar ayuda

# Variables de entorno
export ARGOCD_NAMESPACE=argocd-prod     # Namespace personalizado
export SEVERITY_THRESHOLD=high          # Solo issues críticos
```

## 📋 Reportes Generados

### Estructura de Reportes
```
security_analysis_YYYYMMDD_HHMMSS/
├── executive_summary.md          # Resumen ejecutivo
├── security_report.md           # Reporte principal
├── authentication.md            # Análisis de autenticación
├── authorization.md             # Análisis de RBAC
├── network.md                   # Seguridad de red
└── secrets.md                   # Gestión de secretos
```

### Ejemplo de Resumen Ejecutivo
```markdown
# ArgoCD Security Analysis - Executive Summary

## Overall Security Score
### Security Score: 75/100
🟡 **Overall Status**: Acceptable - Improvements Needed

## Summary Statistics
| Category | Issues | Warnings | Status |
|----------|--------|----------|--------|
| Authentication | 0 | 2 | 🟡 Warning |
| Authorization | 1 | 1 | 🔴 Critical |
| Network Security | 0 | 3 | 🟡 Warning |
| Secrets Management | 0 | 1 | 🟡 Warning |
| **Total** | **1** | **7** | |

## Priority Actions
### 🚨 Critical Issues (Fix Immediately)
- **Authorization**: Review authorization.md for RBAC misconfigurations

### ⚠️ Warnings (Address Soon)
- **Authentication**: 2 warning(s) in authentication configuration
- **Network Security**: 3 warning(s) in network configuration
```

### Ejemplo de Análisis de Autenticación
```markdown
# Authentication Security Analysis

## Configuration Overview

### ArgoCD Configuration
✅ **SSO Configuration**: Dex SSO is configured

**Dex Connectors Found:**
```yaml
- type: github
  name: GitHub OAuth
- type: oidc
  name: Corporate OIDC
```

⚠️ **Initial Admin Secret**: Still exists
- **Risk**: Default admin credentials may be in use
- **Recommendation**: Remove after setting up SSO and proper admin user

### Server Authentication Settings
✅ **Secure Mode**: Server running with TLS enabled
✅ **Authentication Enabled**: Server authentication is properly enabled
```

### Ejemplo de Análisis RBAC
```markdown
# Authorization Security Analysis

## RBAC Configuration

### ArgoCD RBAC ConfigMap
❌ **Default Policy**: Set to admin role
- **Risk**: All authenticated users get admin privileges  
- **Recommendation**: Set to read-only or create specific roles

✅ **Custom Policies**: RBAC policies are defined

**Policy Rules Count:**
- Policy rules: 15
- Role bindings: 8

⚠️ **Permissive Rules**: Found rules with wildcard permissions
- **Risk**: May grant excessive permissions
- **Recommendation**: Review and restrict permissions
```

## 🔍 Categorías de Análisis

### **1. Autenticación**
```bash
# Elementos analizados:
✓ Configuración SSO (Dex, OIDC)
✓ Conectores de autenticación
✓ Cuenta admin inicial
✓ Políticas de contraseñas
✓ Modo seguro/inseguro
✓ Configuración de servidor
```

### **2. Autorización (RBAC)**
```bash
# Elementos analizados:
✓ Política por defecto
✓ Políticas personalizadas CSV
✓ Permisos con wildcards
✓ ClusterRoles de Kubernetes
✓ ServiceAccounts
✓ Configuración de AppProjects
✓ Restricciones de repositorios/destinos
```

### **3. Seguridad de Red**
```bash
# Elementos analizados:
✓ Tipos de servicios (ClusterIP, NodePort, LoadBalancer)
✓ Exposición externa no segura
✓ NetworkPolicies
✓ Configuración de Ingress
✓ Certificados TLS
✓ Segmentación de red
```

### **4. Gestión de Secretos**
```bash
# Elementos analizados:
✓ Inventario de secretos
✓ Contraseña admin
✓ Credenciales de repositorios
✓ Secretos de clusters
✓ Fortaleza de claves SSH
✓ Cifrado de etcd
✓ Gestión externa de secretos
```

## 🎯 Casos de Uso Comunes

### **1. Auditoría de Seguridad Periódica**
```bash
# Ejecutar análisis mensual
./security_analyzer.sh -n argocd-prod

# Comparar con baseline anterior
diff baseline_security/ security_analysis_*/executive_summary.md

# Generar reporte de cumplimiento
cat security_analysis_*/executive_summary.md > monthly_security_report.md
```

### **2. Pre-despliegue en Producción**
```bash
# Análisis completo antes de prod
./security_analyzer.sh --threshold low

# Verificar que no hay issues críticos
if grep -q "🔴" security_analysis_*/executive_summary.md; then
    echo "Critical security issues found - deployment blocked"
    exit 1
fi

echo "Security validation passed - safe to deploy"
```

### **3. Compliance y Regulaciones**
```bash
# Generar reporte para auditoría SOC2
./security_analyzer.sh -t low > soc2_argocd_security.txt

# Generar evidencia para ISO27001
tar -czf iso27001_argocd_evidence.tar.gz security_analysis_*

# Revisar específicamente RBAC para compliance
cat security_analysis_*/authorization.md
```

### **4. Respuesta a Incidentes de Seguridad**
```bash
# Análisis inmediato tras incidente
./security_analyzer.sh -n argocd-prod

# Revisar configuraciones comprometidas
grep -i "critical\|risk" security_analysis_*/*.md

# Generar plan de remediación
cat security_analysis_*/executive_summary.md | grep -A 10 "Priority Actions"
```

## 🚨 Interpretación de Resultados

### **Sistema de Puntuación**
```bash
# Cálculo del score de seguridad:
Base Score: 100 puntos
- Issues críticos: -20 puntos cada uno
- Warnings: -5 puntos cada uno

# Rangos de interpretación:
80-100: 🟢 Excelente seguridad
60-79:  🟡 Aceptable, mejorar
0-59:   🔴 Crítico, acción inmediata
```

### **Niveles de Severidad**
- **🚨 Critical**: Vulnerabilidades que requieren acción inmediata
- **⚠️ Warning**: Configuraciones subóptimas que aumentan riesgo
- **ℹ️ Info**: Recomendaciones de mejores prácticas

### **Códigos de Estado por Categoría**
- **🟢 Good**: Sin problemas detectados
- **🟡 Warning**: Problemas menores identificados  
- **🔴 Critical**: Problemas críticos que requieren atención inmediata

## 🔧 Remediación de Issues Comunes

### **Authentication Issues**
```bash
# Issue: Admin default password
kubectl delete secret argocd-initial-admin-secret -n argocd

# Issue: No SSO configured
kubectl patch configmap argocd-cm -n argocd --patch '
data:
  dex.config: |
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: $GITHUB_CLIENT_ID
        clientSecret: $GITHUB_CLIENT_SECRET
'

# Issue: Insecure mode enabled
kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '
data:
  server.insecure: "false"
'
```

### **Authorization Issues**
```bash
# Issue: Default policy too permissive
kubectl patch configmap argocd-rbac-cm -n argocd --patch '
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:readonly, applications, get, */*, allow
    g, admins, role:admin
'

# Issue: Wildcard permissions
# Review and restrict policy.csv to specific resources
```

### **Network Security Issues**
```bash
# Issue: Insecure service exposure
kubectl patch service argocd-server -n argocd --patch '
spec:
  type: ClusterIP
'

# Issue: Missing NetworkPolicies
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
EOF

# Issue: Missing TLS configuration
# Configure proper TLS certificates for Ingress
```

### **Secrets Management Issues**
```bash
# Issue: Weak admin password
kubectl patch secret argocd-secret -n argocd --patch '
data:
  admin.password: '$(echo -n 'NewStrongPassword123!' | base64)'
'

# Issue: Insecure SSH keys
# Generate new ED25519 key
ssh-keygen -t ed25519 -f argocd_deploy_key

# Update repository secret with new key
kubectl create secret generic repo-ssh-key \
  --from-file=sshPrivateKey=argocd_deploy_key \
  --from-literal=type=git \
  --from-literal=url=git@github.com:org/repo.git \
  -n argocd
```

## 📊 Integración y Automatización

### **CI/CD Integration**
```yaml
# .github/workflows/security-scan.yml
name: ArgoCD Security Scan
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2 AM
  workflow_dispatch:

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
      - name: Run Security Analysis
        run: |
          ./Security_analyzer/security_analyzer.sh -n argocd-prod
          
          # Fail if critical issues found
          if grep -q "🔴.*Critical" security_analysis_*/executive_summary.md; then
            echo "::error::Critical security issues detected"
            cat security_analysis_*/executive_summary.md
            exit 1
          fi
      - name: Upload Security Report
        uses: actions/upload-artifact@v3
        with:
          name: security-analysis-report
          path: security_analysis_*
```

### **Alerting Integration**
```bash
# Script de alertas automáticas
#!/bin/bash
./security_analyzer.sh -n argocd-prod

# Extraer score de seguridad
SECURITY_SCORE=$(grep "Security Score:" security_analysis_*/executive_summary.md | awk '{print $3}' | cut -d'/' -f1)

# Alertar si score bajo
if [ "$SECURITY_SCORE" -lt 70 ]; then
    curl -X POST $SLACK_WEBHOOK_URL -H 'Content-type: application/json' \
      --data "{\"text\":\"🚨 ArgoCD Security Score Low: $SECURITY_SCORE/100\"}"
fi

# Alertar por issues críticos
if grep -q "🔴" security_analysis_*/executive_summary.md; then
    curl -X POST $TEAMS_WEBHOOK_URL -H 'Content-type: application/json' \
      --data '{"text":"Critical ArgoCD security issues detected - immediate action required"}'
fi
```

### **Métricas para Prometheus**
```bash
# Exportar métricas de seguridad
#!/bin/bash
LATEST_REPORT=$(ls -td security_analysis_* | head -1)

# Score de seguridad
SCORE=$(grep "Security Score:" $LATEST_REPORT/executive_summary.md | awk '{print $3}' | cut -d'/' -f1)
echo "argocd_security_score $SCORE" > /var/lib/node_exporter/textfile_collector/argocd_security.prom

# Issues por categoría
CRITICAL_ISSUES=$(grep -c "🔴" $LATEST_REPORT/executive_summary.md)
WARNING_ISSUES=$(grep -c "🟡" $LATEST_REPORT/executive_summary.md)

echo "argocd_security_critical_issues $CRITICAL_ISSUES" >> /var/lib/node_exporter/textfile_collector/argocd_security.prom
echo "argocd_security_warning_issues $WARNING_ISSUES" >> /var/lib/node_exporter/textfile_collector/argocd_security.prom
```

## 📚 Mejores Prácticas

### **Configuración Segura Base**
```yaml
# argocd-secure-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Require HTTPS
  server.insecure: "false"
  
  # Configure SSO
  dex.config: |
    connectors:
    - type: oidc
      id: corporate-sso
      name: Corporate SSO
      config:
        issuer: https://sso.company.com
        clientID: argocd
        clientSecret: $dex.corporate-sso.client-secret
  
  # Disable local users (after SSO setup)
  accounts.admin: apiKey
  accounts.alice: apiKey,login
  
---
apiVersion: v1
kind: ConfigMap  
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Restrictive default
  policy.default: role:readonly
  
  # Granular permissions
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:devops, applications, *, myteam/*, allow
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, clusters, get, *, allow
    
    g, alice@company.com, role:admin
    g, devops-team, role:devops
```

### **Security Checklist**
```markdown
## ArgoCD Security Checklist

### Authentication ✓
- [ ] SSO configured and tested
- [ ] Initial admin secret removed
- [ ] Strong admin passwords enforced
- [ ] MFA enabled where possible
- [ ] Local accounts minimized

### Authorization ✓  
- [ ] Default policy set to readonly
- [ ] Granular RBAC policies defined
- [ ] No wildcard permissions in production
- [ ] Project-level restrictions configured
- [ ] Regular permission audits scheduled

### Network Security ✓
- [ ] TLS enabled for all communications
- [ ] Services not directly exposed to internet
- [ ] Ingress properly configured with TLS
- [ ] NetworkPolicies implemented
- [ ] Regular network security reviews

### Secrets Management ✓
- [ ] External secret management in use
- [ ] Repository credentials rotated regularly
- [ ] Strong SSH keys (ED25519 preferred)
- [ ] Cluster credentials certificate-based
- [ ] Secrets encrypted at rest (etcd)

### Monitoring ✓
- [ ] Security audit logging enabled
- [ ] Regular security scans automated
- [ ] Alerting for security events
- [ ] Performance monitoring active
- [ ] Compliance reporting automated
```

---

**🎯 Objetivo**: Garantizar que las instalaciones de ArgoCD cumplan con los más altos estándares de seguridad mediante análisis automatizado, reportes detallados y recomendaciones accionables.