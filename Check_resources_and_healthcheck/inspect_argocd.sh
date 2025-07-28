#!/bin/bash

set -euo pipefail

RELEASE_NAME="${1:-argocd}"
NAMESPACE="${2:-argocd}"
OUTPUT="${3:-argocd_inspection_report.md}"

check_dependencies() {
    local deps=("kubectl" "helm" "jq" "yq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "❌ Missing required dependencies: ${missing[*]}"
        echo "Please install them and try again."
        exit 1
    fi
}

cleanup() {
    [ -f "values.yaml" ] && rm -f "values.yaml"
}

trap cleanup EXIT

check_dependencies

echo "🔎 Iniciando inspección de ArgoCD..."
echo "   Namespace: $NAMESPACE"
echo "   Release: $RELEASE_NAME"
echo "   Output: $OUTPUT"
echo ""

echo "# 🔎 Reporte de Inspección de ArgoCD" > "$OUTPUT"
echo "Namespace: \`$NAMESPACE\` | Release: \`$RELEASE_NAME\`" >> "$OUTPUT"
echo "Fecha: \`$(date '+%Y-%m-%d %H:%M:%S')\`" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "## 📦 Verificando release Helm..." | tee -a "$OUTPUT"
if ! helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
  echo "❌ Release '$RELEASE_NAME' no encontrado en el namespace '$NAMESPACE'." | tee -a "$OUTPUT"
  exit 1
else
  echo "✅ Release encontrado" >> "$OUTPUT"
fi

if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "❌ Namespace '$NAMESPACE' no existe." | tee -a "$OUTPUT"
  exit 1
fi

echo "" >> "$OUTPUT"
echo "## ⚙️ Valores relevantes del Helm Chart" >> "$OUTPUT"

if ! helm get values "$RELEASE_NAME" -n "$NAMESPACE" > values.yaml 2>/dev/null; then
  echo "❌ Error obteniendo valores del release Helm" | tee -a "$OUTPUT"
  exit 1
fi

echo "### 🌐 URL configurada" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
yq '.configs."cm".server\\.url // "No definida"' values.yaml >> "$OUTPUT"
echo '```' >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 🔐 Dex.config (SSO GitHub)" >> "$OUTPUT"
echo '```yaml' >> "$OUTPUT"
yq '.configs."cm".dex\\.config // "No definido"' values.yaml >> "$OUTPUT"
echo '```' >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "### 🔒 policy.csv (RBAC)" >> "$OUTPUT"
echo '```csv' >> "$OUTPUT"
yq '.configs."rbac".policy\\.csv // "No definido"' values.yaml >> "$OUTPUT"
echo '```' >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "## 🚑 Liveness y Readiness Probes por Pod" >> "$OUTPUT"

if ! kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/part-of=argocd -o json 2>/dev/null | jq -r '
  .items[] |
  "### Pod: \(.metadata.name)" + 
  " (Status: \(.status.phase))\n" +
  (
    .spec.containers[] |
    "#### Container: \(.name)\n" +
    (if .livenessProbe then
      "**✅ LivenessProbe:**\n" +
      "- initialDelaySeconds: \(.livenessProbe.initialDelaySeconds // "N/A")\n" +
      "- periodSeconds: \(.livenessProbe.periodSeconds // "N/A")\n" +
      "- failureThreshold: \(.livenessProbe.failureThreshold // "N/A")\n" +
      "- timeoutSeconds: \(.livenessProbe.timeoutSeconds // "N/A")\n" +
      (
        if (.livenessProbe.initialDelaySeconds // 0) > 30 then "- ⚠️ initialDelaySeconds es muy alto (>30s)\n" else "" end +
        if (.livenessProbe.periodSeconds // 0) > 15 then "- ⚠️ periodSeconds debería ser <= 15s\n" else "" end +
        if (.livenessProbe.failureThreshold // 0) > 5 then "- ⚠️ failureThreshold demasiado permisivo (>5)\n" else "" end +
        if (.livenessProbe.timeoutSeconds // 0) > 5 then "- ⚠️ timeoutSeconds elevado (>5s)\n" else "" end
      )
    else "**❌ No LivenessProbe definido**\n" end) +
    "\n" +
    (if .readinessProbe then
      "**✅ ReadinessProbe:**\n" +
      "- initialDelaySeconds: \(.readinessProbe.initialDelaySeconds // "N/A")\n" +
      "- periodSeconds: \(.readinessProbe.periodSeconds // "N/A")\n" +
      "- failureThreshold: \(.readinessProbe.failureThreshold // "N/A")\n" +
      "- timeoutSeconds: \(.readinessProbe.timeoutSeconds // "N/A")\n" +
      (
        if (.readinessProbe.initialDelaySeconds // 0) > 30 then "- ⚠️ initialDelaySeconds es muy alto (>30s)\n" else "" end +
        if (.readinessProbe.periodSeconds // 0) > 15 then "- ⚠️ periodSeconds debería ser <= 15s\n" else "" end +
        if (.readinessProbe.failureThreshold // 0) > 5 then "- ⚠️ failureThreshold demasiado permisivo (>5)\n" else "" end +
        if (.readinessProbe.timeoutSeconds // 0) > 5 then "- ⚠️ timeoutSeconds elevado (>5s)\n" else "" end
      )
    else "**❌ No ReadinessProbe definido**\n" end) +
    "\n---\n"
  )
' >> "$OUTPUT"; then
  echo "❌ Error obteniendo información de pods" | tee -a "$OUTPUT"
fi

echo "" >> "$OUTPUT"
echo "## 📊 Recursos (CPU/Memory)" >> "$OUTPUT"
kubectl -n "$NAMESPACE" top pods -l app.kubernetes.io/part-of=argocd 2>/dev/null | tail -n +2 | while read -r line; do
  echo "- \`$line\`" >> "$OUTPUT"
done 2>/dev/null || echo "⚠️ Metrics server no disponible para mostrar uso de recursos" >> "$OUTPUT"

echo ""
echo "✅ Reporte generado: $OUTPUT"
echo "📄 Para ver el reporte: cat $OUTPUT"
