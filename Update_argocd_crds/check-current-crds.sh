#!/bin/bash

# Script para verificar la versión actual de CRDs de ArgoCD
# y determinar si necesitan actualización

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Verificando CRDs actuales de ArgoCD...${NC}"
echo "=============================================="

# Verificar si los CRDs existen
echo -e "${YELLOW}📋 CRDs de ArgoCD encontrados:${NC}"
kubectl get crd | grep -E "(argoproj\.io)" | while read line; do
    echo -e "  ${GREEN}✅${NC} $line"
done

echo
echo -e "${YELLOW}🏷️  Versiones de CRDs actuales:${NC}"

# Verificar Application CRD
if kubectl get crd applications.argoproj.io &> /dev/null; then
    echo -e "${BLUE}📱 Application CRD:${NC}"
    kubectl get crd applications.argoproj.io -o jsonpath='{.spec.versions[*].name}' | tr ' ' '\n' | sort | tail -1 | xargs echo "   Versión más reciente:"
    
    # Obtener anotaciones que pueden indicar la versión de ArgoCD
    echo "   Anotaciones relevantes:"
    annotations=$(kubectl get crd applications.argoproj.io -o jsonpath='{.metadata.annotations}' 2>/dev/null)
    if [ ! -z "$annotations" ] && command -v jq &> /dev/null; then
        echo "$annotations" | jq -r '. | to_entries[] | select(.key | contains("argocd") or contains("version") or contains("chart")) | "     \(.key): \(.value)"' 2>/dev/null || echo "     Sin anotaciones de versión específicas"
    else
        echo "     Sin anotaciones de versión o jq no disponible"
    fi
    
    # Mostrar fecha de creación
    echo -n "   Creado: "
    kubectl get crd applications.argoproj.io -o jsonpath='{.metadata.creationTimestamp}'
    echo
else
    echo -e "${RED}❌ Application CRD no encontrado${NC}"
fi

echo

# Verificar AppProject CRD
if kubectl get crd appprojects.argoproj.io &> /dev/null; then
    echo -e "${BLUE}🗂️  AppProject CRD:${NC}"
    kubectl get crd appprojects.argoproj.io -o jsonpath='{.spec.versions[*].name}' | tr ' ' '\n' | sort | tail -1 | xargs echo "   Versión más reciente:"
    echo -n "   Creado: "
    kubectl get crd appprojects.argoproj.io -o jsonpath='{.metadata.creationTimestamp}'
    echo
else
    echo -e "${RED}❌ AppProject CRD no encontrado${NC}"
fi

echo

# Verificar ApplicationSet CRD
if kubectl get crd applicationsets.argoproj.io &> /dev/null; then
    echo -e "${BLUE}📚 ApplicationSet CRD:${NC}"
    kubectl get crd applicationsets.argoproj.io -o jsonpath='{.spec.versions[*].name}' | tr ' ' '\n' | sort | tail -1 | xargs echo "   Versión más reciente:"
    echo -n "   Creado: "
    kubectl get crd applicationsets.argoproj.io -o jsonpath='{.metadata.creationTimestamp}'
    echo
else
    echo -e "${RED}❌ ApplicationSet CRD no encontrado${NC}"
fi

echo
echo -e "${YELLOW}🎯 Tu configuración actual de ArgoCD:${NC}"
echo "   Imagen: 806145550734.dkr.ecr.eu-west-1.amazonaws.com/nexus/argocd:v2.14.11-pr-patch-1358.1"
echo "   Versión base: v2.14.11"

echo
echo -e "${YELLOW}🔗 Verificando compatibilidad:${NC}"

# Verificar versión del servidor ArgoCD actual
echo -e "${BLUE}📊 Versión del servidor ArgoCD:${NC}"
if kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server &> /dev/null; then
    SERVER_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$SERVER_POD" ]; then
        echo "   Pod del servidor: $SERVER_POD"
        echo "   Imagen actual:"
        kubectl get pod $SERVER_POD -n argocd -o jsonpath='{.spec.containers[0].image}' | xargs echo "     "
        
        echo "   Logs de inicio (versión):"
        kubectl logs $SERVER_POD -n argocd --tail=50 | grep -i "version\|starting\|argocd" | head -3 2>/dev/null || echo "     No se pudo obtener información de versión"
    fi
else
    echo -e "   ${YELLOW}⚠️  No se encontraron pods del servidor ArgoCD${NC}"
fi

echo
echo -e "${YELLOW}📈 Estado de recursos ArgoCD:${NC}"
echo -n "   Applications: "
kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | wc -l | xargs echo
echo -n "   Projects: "
kubectl get appprojects.argoproj.io -A --no-headers 2>/dev/null | wc -l | xargs echo
echo -n "   ApplicationSets: "
kubectl get applicationsets.argoproj.io -A --no-headers 2>/dev/null | wc -l | xargs echo

echo
echo -e "${GREEN}🎯 Recomendación:${NC}"
echo "   Los CRDs deben estar alineados con la versión v2.14.11"
echo "   para compatibilidad óptima con tu imagen personalizada."

echo
echo -e "${BLUE}💡 Siguiente paso:${NC}"
echo "   Si necesitas actualizar, ejecuta:"
echo -e "   ${YELLOW}./argocd-crd-updater.sh${NC}"

# Verificar si hay una diferencia significativa
echo
echo -e "${YELLOW}🔍 Análisis rápido:${NC}"
current_version=$(kubectl get crd applications.argoproj.io -o jsonpath='{.spec.versions[*].name}' 2>/dev/null | tr ' ' '\n' | sort | tail -1)
if [ "$current_version" = "v1alpha1" ]; then
    echo -e "   ${GREEN}✅ CRDs parecen estar actualizados (v1alpha1)${NC}"
elif [ "$current_version" = "v1beta1" ]; then
    echo -e "   ${YELLOW}⚠️  CRDs en versión beta - considera actualizar${NC}"
else
    echo -e "   ${RED}❓ Versión de CRD no reconocida: $current_version${NC}"
fi