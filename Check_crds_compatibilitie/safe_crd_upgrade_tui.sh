#!/bin/bash
set -euo pipefail

BACKUP_DIR="crd_backups"

# Requisitos
for tool in gum yq kubectl git; do
  if ! command -v "$tool" &>/dev/null; then
    echo "❌ $tool no está instalado. Instálalo antes de continuar."
    exit 1
  fi
done

# Tomar las últimas 10 versiones disponibles
VERSIONS=$(git ls-remote --tags https://github.com/argoproj/argo-cd.git |
  awk -F'/' '{print $3}' |
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
  sort -Vr | head -n 10)

ARGOCD_VERSION=$(printf "%s\n" $VERSIONS | gum choose --header="🔢 Seleccioná la versión de Argo CD")

CLONE_DIR="tmp-argocd-${ARGOCD_VERSION}"

if [[ ! -d "$CLONE_DIR" ]]; then
  echo "📥 Clonando ArgoCD $ARGOCD_VERSION..."
  git clone --depth 1 --branch "$ARGOCD_VERSION" https://github.com/argoproj/argo-cd.git "$CLONE_DIR"
else
  echo "✅ Repositorio ArgoCD ya disponible en $CLONE_DIR"
fi

CRD_DIR="$CLONE_DIR/manifests/crds"
mkdir -p "$BACKUP_DIR"

mapfile -t CRD_FILES < <(find "$CRD_DIR" -name '*-crd.yaml' | sort)

SELECTED_FILE=$(printf "%s\n" "${CRD_FILES[@]}" | gum choose --header="🧠 Seleccioná un CRD para validar y aplicar")

CRD_NAME=$(yq e '.metadata.name' "$SELECTED_FILE")
CRD_KIND=$(yq e '.spec.names.kind' "$SELECTED_FILE" | tr -d '\n')

echo
gum style --foreground 212 "🧪 CRD seleccionado: $CRD_NAME ($CRD_KIND)"
echo

BACKUP_FILE="$BACKUP_DIR/${CRD_NAME}-backup.yaml"
echo "💾 Guardando backup en: $BACKUP_FILE"
kubectl get crd "$CRD_NAME" -o yaml > "$BACKUP_FILE"

echo "🔍 Buscando recursos de tipo $CRD_KIND..."
RESOURCES=$(kubectl get "$CRD_KIND" --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace --no-headers 2>/dev/null || true)

if [[ -z "$RESOURCES" ]]; then
  gum style --foreground 10 "✅ No hay recursos de tipo $CRD_KIND"
else
  while read -r NAME NAMESPACE; do
    [[ -z "$NAME" || -z "$NAMESPACE" ]] && continue
    if kubectl get "$CRD_KIND" "$NAME" -n "$NAMESPACE" -o yaml | kubectl apply --dry-run=server -f - &>/dev/null; then
      gum style --foreground 10 "✅ $CRD_KIND/$NAME (ns: $NAMESPACE) válido"
    else
      gum style --foreground 9 "❌ $CRD_KIND/$NAME (ns: $NAMESPACE) incompatible"
    fi
  done <<< "$RESOURCES"
fi

echo
gum style --foreground 6 "🧠 Mostrando diff:"
kubectl diff -f "$SELECTED_FILE" || echo "(sin diferencias)"

echo
if gum confirm "¿Querés aplicar este CRD?"; then
  kubectl apply -f "$SELECTED_FILE"
  gum style --foreground 10 "✅ CRD $CRD_NAME aplicado."
else
  gum style --foreground 9 "❌ Operación cancelada."
fi
