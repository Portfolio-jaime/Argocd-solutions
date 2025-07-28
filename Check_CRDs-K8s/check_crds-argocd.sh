#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Iconos
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="ℹ️"
GEAR="⚙️"
CHART="📊"
VERSION="🏷️"
COMPATIBLE="✨"
INCOMPATIBLE="💥"
ROCKET="🚀"
CLUSTER="🏗️"
UPDATE="🔄"
SECURITY="🔒"

# Función para imprimir encabezados
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}    $1${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Función para imprimir tabla
print_table_header() {
    local title="$1"
    echo -e "${BOLD}${CYAN}┌────────────────────────────────────────────────────────────────────────────────┐${NC}"
    printf "${BOLD}${CYAN}│${WHITE}%*s%s%*s${CYAN}│${NC}\n" $(( (78 - ${#title}) / 2 )) "" "$title" $(( (78 - ${#title}) / 2 )) ""
    echo -e "${BOLD}${CYAN}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
}

print_table_footer() {
    echo -e "${BOLD}${CYAN}└────────────────────────────────────────────────────────────────────────────────┘${NC}"
}

print_table_separator() {
    echo -e "${BOLD}${CYAN}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
}

# Función para obtener versión de imagen
get_image_version() {
    local image="$1"
    echo "$image" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1
}

# Función para comparar versiones semánticas
version_ge() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Función para obtener información del cluster EKS
get_eks_info() {
    local cluster_name=""
    local k8s_version=""
    local region=""
    
    # Intentar obtener información del cluster
    if command -v aws >/dev/null 2>&1; then
        local current_context=$(kubectl config current-context 2>/dev/null)
        if [[ "$current_context" == *"eks"* ]]; then
            cluster_name=$(echo "$current_context" | grep -o '[^/]*$')
            region=$(echo "$current_context" | grep -o 'arn:aws:eks:[^:]*' | cut -d':' -f4)
        fi
    fi
    
    # Obtener versión de Kubernetes de forma compatible
    k8s_version=$(kubectl version --output=json 2>/dev/null | grep -o '"serverVersion":{"major":"[^"]*","minor":"[^"]*"' | sed 's/.*"major":"\([^"]*\)","minor":"\([^"]*\)".*/v\1.\2/' 2>/dev/null)
    if [ -z "$k8s_version" ]; then
        k8s_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | cut -d' ' -f3 2>/dev/null || echo "No detectada")
    fi
    
    echo "$cluster_name|$k8s_version|$region"
}

# Función para verificar compatibilidad CRD detallada
check_detailed_crd_compatibility() {
    local argocd_version="$1"
    local crd_name="$2"
    local crd_versions="$3"
    local crd_creation_date="$4"
    
    case "$crd_name" in
        "applications.argoproj.io")
            if [[ "$crd_versions" == *"v1beta1"* ]] && [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${GREEN}${COMPATIBLE} Compatible completo${NC}|OK|Soporta ambas APIs necesarias"
            elif [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${YELLOW}${WARNING} Requiere actualización${NC}|ACTUALIZAR|Falta soporte v1beta1 - Argo CD 2.5+ requiere esta API para nuevas funcionalidades"
            else
                echo "${RED}${INCOMPATIBLE} Incompatible${NC}|CRÍTICO|CRD corrupto o versión muy antigua - Requiere reinstalación completa"
            fi
            ;;
        "applicationsets.argoproj.io")
            if [[ "$crd_versions" == *"v1alpha1"* ]] && version_ge "$argocd_version" "v2.3.0"; then
                echo "${GREEN}${COMPATIBLE} Compatible${NC}|OK|ApplicationSets funcional"
            elif [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${YELLOW}${WARNING} Versión Argo CD antigua${NC}|ACTUALIZAR|ApplicationSets requiere Argo CD >= 2.3.0"
            else
                echo "${RED}${INCOMPATIBLE} CRD faltante${NC}|CRÍTICO|ApplicationSets no funcionará correctamente"
            fi
            ;;
        "appprojects.argoproj.io")
            if [[ "$crd_versions" == *"v1alpha1"* ]]; then
                echo "${GREEN}${COMPATIBLE} Compatible${NC}|OK|Projects funcionando correctamente"
            else
                echo "${RED}${INCOMPATIBLE} CRD faltante${NC}|CRÍTICO|RBAC de proyectos no funcionará"
            fi
            ;;
    esac
}

# Función para calcular diferencia de días
calculate_date_diff() {
    local date1="$1"
    local date2="$2"
    
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
from datetime import datetime
try:
    d1 = datetime.strptime('$date1', '%Y-%m-%d')
    d2 = datetime.strptime('$date2', '%Y-%m-%d')
    print(abs((d2 - d1).days))
except:
    print('Error')
" 2>/dev/null
    elif command -v python >/dev/null 2>&1; then
        python -c "
from datetime import datetime  
try:
    d1 = datetime.strptime('$date1', '%Y-%m-%d')
    d2 = datetime.strptime('$date2', '%Y-%m-%d')
    print(abs((d2 - d1).days))
except:
    print('Error')
" 2>/dev/null
    else
        echo "Error"
    fi
}

# Función para obtener recomendaciones de actualización
get_update_recommendations() {
    local argocd_version="$1"
    local chart_version="$2"
    local helm_release="$3"
    
    echo ""
    echo -e "${BOLD}${PURPLE}${ROCKET} PLAN DE ACTUALIZACIÓN RECOMENDADO:${NC}"
    echo ""
    
    # Verificar versión actual vs disponible
    if command -v helm >/dev/null 2>&1; then
        local latest_chart=$(helm search repo argo/argo-cd --output json 2>/dev/null | jq -r '.[0].version' 2>/dev/null || echo "No disponible")
        local latest_app=$(helm search repo argo/argo-cd --output json 2>/dev/null | jq -r '.[0].app_version' 2>/dev/null || echo "No disponible")
        
        echo -e "${INFO} ${BOLD}Versiones disponibles:${NC}"
        echo -e "  • Chart más reciente: ${GREEN}$latest_chart${NC}"
        echo -e "  • App más reciente: ${GREEN}$latest_app${NC}"
        echo -e "  • Tu Chart actual: ${BLUE}$chart_version${NC}"
        echo -e "  • Tu App actual: ${BLUE}$argocd_version${NC}"
        echo ""
    fi
    
    echo -e "${BOLD}${YELLOW}1. PRE-ACTUALIZACIÓN (CRÍTICO):${NC}"
    echo -e "   ${WARNING} Realizar backup de aplicaciones:"
    echo -e "   ${CYAN}kubectl get applications -n argocd -o yaml > backup-applications.yaml${NC}"
    echo -e "   ${CYAN}kubectl get appprojects -n argocd -o yaml > backup-projects.yaml${NC}"
    echo ""
    
    echo -e "${BOLD}${BLUE}2. ACTUALIZACIÓN DE CRDs:${NC}"
    echo -e "   ${INFO} Los CRDs deben actualizarse ANTES que la aplicación:"
    echo -e "   ${CYAN}# Descargar CRDs de la versión objetivo${NC}"
    echo -e "   ${CYAN}curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/application-crd.yaml | kubectl apply -f -${NC}"
    echo -e "   ${CYAN}curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/applicationset-crd.yaml | kubectl apply -f -${NC}"
    echo -e "   ${CYAN}curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/appproject-crd.yaml | kubectl apply -f -${NC}"
    echo ""
    
    echo -e "${BOLD}${GREEN}3. ACTUALIZACIÓN VIA HELM:${NC}"
    echo -e "   ${CYAN}helm repo update${NC}"
    echo -e "   ${CYAN}helm upgrade $helm_release argo/argo-cd -n argocd \\${NC}"
    echo -e "   ${CYAN}    --reuse-values \\${NC}"
    echo -e "   ${CYAN}    --wait --timeout=600s${NC}"
    echo ""
    
    echo -e "${BOLD}${PURPLE}4. POST-ACTUALIZACIÓN:${NC}"
    echo -e "   ${INFO} Verificar que los pods estén corriendo:"
    echo -e "   ${CYAN}kubectl get pods -n argocd${NC}"
    echo -e "   ${INFO} Verificar aplicaciones:"
    echo -e "   ${CYAN}kubectl get applications -n argocd${NC}"
    echo -e "   ${INFO} Re-ejecutar este script para verificar compatibilidad"
    echo ""
    
    echo -e "${BOLD}${RED}5. CONSIDERACIONES EKS:${NC}"
    echo -e "   ${WARNING} Verificar que la versión de K8s sea compatible"
    echo -e "   ${WARNING} Los CRDs se almacenan en etcd - hacer backup si es crítico"
    echo -e "   ${WARNING} Rollback disponible con: ${CYAN}helm rollback $helm_release${NC}"
}

print_header "${GEAR} ANÁLISIS COMPLETO CRDs ARGO CD PARA EKS"

# Obtener información del cluster EKS
EKS_INFO=$(get_eks_info)
EKS_CLUSTER=$(echo "$EKS_INFO" | cut -d'|' -f1)
K8S_VERSION=$(echo "$EKS_INFO" | cut -d'|' -f2)
EKS_REGION=$(echo "$EKS_INFO" | cut -d'|' -f3)

# Mostrar información del cluster
print_table_header "INFORMACIÓN DEL CLUSTER EKS"
echo -e "${BOLD}${CYAN}│${NC} Cluster EKS: ${GREEN}${EKS_CLUSTER:-"No detectado"}${NC}"
echo -e "${BOLD}${CYAN}│${NC} Versión Kubernetes: ${BLUE}$K8S_VERSION${NC}"
echo -e "${BOLD}${CYAN}│${NC} Región AWS: ${PURPLE}${EKS_REGION:-"No detectada"}${NC}"
echo -e "${BOLD}${CYAN}│${NC} Contexto actual: ${YELLOW}$(kubectl config current-context 2>/dev/null || echo "No disponible")${NC}"
print_table_footer

# 1. Recopilar información de Argo CD
echo -e "${BOLD}${PURPLE}${INFO} Recopilando información de Argo CD...${NC}"

ARGOCD_NAMESPACE="argocd"
HELM_RELEASE=""
CHART_VERSION=""
IMAGE_VERSION=""
ARGOCD_IMAGE=""

if kubectl get namespace $ARGOCD_NAMESPACE >/dev/null 2>&1; then
    echo -e "${GREEN}${CHECK} Namespace '$ARGOCD_NAMESPACE' encontrado${NC}"
    
    # Información de Helm
    if command -v helm >/dev/null 2>&1; then
        HELM_INFO=$(helm list -n $ARGOCD_NAMESPACE -o json 2>/dev/null | jq -r '.[] | select(.name | test("argo")) | "\(.name)|\(.chart)|\(.app_version)"' 2>/dev/null | head -1)
        if [ ! -z "$HELM_INFO" ]; then
            HELM_RELEASE=$(echo "$HELM_INFO" | cut -d'|' -f1)
            CHART_VERSION=$(echo "$HELM_INFO" | cut -d'|' -f2)
            HELM_APP_VERSION=$(echo "$HELM_INFO" | cut -d'|' -f3)
        fi
    fi
    
    # Imagen del servidor
    ARGOCD_IMAGE=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null)
    if [ ! -z "$ARGOCD_IMAGE" ]; then
        IMAGE_VERSION=$(get_image_version "$ARGOCD_IMAGE")
    fi
else
    echo -e "${RED}${ERROR} Namespace '$ARGOCD_NAMESPACE' no encontrado${NC}"
    exit 1
fi

# 2. Información de instalación
print_table_header "INSTALACIÓN ARGO CD"
if [ ! -z "$HELM_RELEASE" ]; then
    echo -e "${BOLD}${CYAN}│${NC} ${CHART} Helm Release: ${GREEN}$HELM_RELEASE${NC}"
    echo -e "${BOLD}${CYAN}│${NC} ${VERSION} Chart Version: ${GREEN}$CHART_VERSION${NC}"
    [ ! -z "$HELM_APP_VERSION" ] && echo -e "${BOLD}${CYAN}│${NC} ${VERSION} Helm App Version: ${GREEN}$HELM_APP_VERSION${NC}"
else
    echo -e "${BOLD}${CYAN}│${NC} ${WARNING} Instalación: ${YELLOW}Manual (No Helm)${NC}"
fi

if [ ! -z "$ARGOCD_IMAGE" ]; then
    DISPLAY_IMAGE="$ARGOCD_IMAGE"
    [ ${#ARGOCD_IMAGE} -gt 60 ] && DISPLAY_IMAGE="...${ARGOCD_IMAGE: -57}"
    echo -e "${BOLD}${CYAN}│${NC} ${GEAR} Imagen: ${BLUE}$DISPLAY_IMAGE${NC}"
fi

[ ! -z "$IMAGE_VERSION" ] && echo -e "${BOLD}${CYAN}│${NC} ${VERSION} Versión Detectada: ${GREEN}$IMAGE_VERSION${NC}" || echo -e "${BOLD}${CYAN}│${NC} ${ERROR} Versión: ${RED}No detectada${NC}"
print_table_footer

# 3. Análisis detallado de CRDs
echo ""
echo -e "${BOLD}${PURPLE}${INFO} Analizando CRDs de Argo CD con detalles de compatibilidad...${NC}"

print_table_header "ANÁLISIS DETALLADO DE COMPATIBILIDAD"
echo -e "${BOLD}${CYAN}│${NC} ${BOLD}CRD${NC}                     ${BOLD}│${NC} ${BOLD}APIs${NC}         ${BOLD}│${NC} ${BOLD}Estado${NC}              ${BOLD}│${NC} ${BOLD}Fecha${NC}      ${BOLD}${CYAN}│${NC}"
print_table_separator

# Analizar CRDs de Argo CD
ARGOCD_CRDS=("applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io")

# Verificar si el shell soporta arrays asociativos
if [[ $BASH_VERSION =~ ^[4-9] ]]; then
    declare -A CRD_ISSUES=()
    USE_ASSOC_ARRAYS=true
else
    USE_ASSOC_ARRAYS=false
    CRD_ISSUES_LIST=""
fi

for crd in "${ARGOCD_CRDS[@]}"; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
        crd_versions=$(kubectl get crd "$crd" -o jsonpath='{.spec.versions[*].name}')
        crd_date=$(kubectl get crd "$crd" -o jsonpath='{.metadata.creationTimestamp}' | cut -d'T' -f1)
        crd_short=$(echo "$crd" | sed 's/.argoproj.io//')
        
        if [ ! -z "$IMAGE_VERSION" ]; then
            compatibility_result=$(check_detailed_crd_compatibility "$IMAGE_VERSION" "$crd" "$crd_versions" "$crd_date")
            compatibility_status=$(echo "$compatibility_result" | cut -d'|' -f1)
            compatibility_action=$(echo "$compatibility_result" | cut -d'|' -f2)
            compatibility_reason=$(echo "$compatibility_result" | cut -d'|' -f3)
            
            # Guardar problemas para el resumen
            if [[ "$compatibility_action" != "OK" ]]; then
                if [[ "$USE_ASSOC_ARRAYS" == "true" ]]; then
                    CRD_ISSUES["$crd_short"]="$compatibility_action|$compatibility_reason"
                else
                    CRD_ISSUES_LIST="${CRD_ISSUES_LIST}${crd_short}:${compatibility_action}|${compatibility_reason};"
                fi
            fi
        else
            compatibility_status="${YELLOW}${WARNING} No verificable"
            compatibility_action="UNKNOWN"
            compatibility_reason="Versión de Argo CD no detectada"
        fi
        
        printf "${BOLD}${CYAN}│${NC} %-23s ${BOLD}│${NC} %-12s ${BOLD}│${NC} %-23s ${BOLD}│${NC} %-10s ${BOLD}${CYAN}│${NC}\n" \
               "$crd_short" "$crd_versions" "$compatibility_status" "$crd_date"
    else
        crd_short=$(echo "$crd" | sed 's/.argoproj.io//')
        if [[ "$USE_ASSOC_ARRAYS" == "true" ]]; then
            CRD_ISSUES["$crd_short"]="CRÍTICO|CRD completamente faltante"
        else
            CRD_ISSUES_LIST="${CRD_ISSUES_LIST}${crd_short}:CRÍTICO|CRD completamente faltante;"
        fi
        printf "${BOLD}${CYAN}│${NC} ${RED}%-23s${NC} ${BOLD}│${NC} ${RED}%-12s${NC} ${BOLD}│${NC} ${RED}%-23s${NC} ${BOLD}│${NC} ${RED}%-10s${NC} ${BOLD}${CYAN}│${NC}\n" \
               "$crd_short" "FALTANTE" "${ERROR} No encontrado" "N/A"
    fi
done
print_table_footer

# 4. Detalles de problemas encontrados
ISSUES_COUNT=0
if [[ "$USE_ASSOC_ARRAYS" == "true" ]]; then
    ISSUES_COUNT=${#CRD_ISSUES[@]}
else
    ISSUES_COUNT=$(echo "$CRD_ISSUES_LIST" | grep -o ":" | wc -l)
fi

if [ $ISSUES_COUNT -gt 0 ]; then
    echo ""
    print_table_header "PROBLEMAS DETECTADOS Y SOLUCIONES"
    
    if [[ "$USE_ASSOC_ARRAYS" == "true" ]]; then
        for crd in "${!CRD_ISSUES[@]}"; do
            IFS='|' read -r action reason <<< "${CRD_ISSUES[$crd]}"
            echo -e "${BOLD}${CYAN}│${NC}"
            case $action in
                "ACTUALIZAR")
                    echo -e "${BOLD}${CYAN}│${NC} ${YELLOW}${WARNING} $crd:${NC} $reason"
                    echo -e "${BOLD}${CYAN}│${NC} ${INFO} ${BOLD}Solución:${NC} Actualizar CRDs antes que la aplicación"
                    ;;
                "CRÍTICO")
                    echo -e "${BOLD}${CYAN}│${NC} ${RED}${ERROR} $crd:${NC} $reason"
                    echo -e "${BOLD}${CYAN}│${NC} ${INFO} ${BOLD}Solución:${NC} Reinstalar CRDs inmediatamente"
                    ;;
            esac
            echo -e "${BOLD}${CYAN}│${NC}"
        done
    else
        # Procesar lista de problemas para shells más antiguos
        IFS=';' read -ra ISSUE_ARRAY <<< "$CRD_ISSUES_LIST"
        for issue in "${ISSUE_ARRAY[@]}"; do
            if [ ! -z "$issue" ]; then
                crd=$(echo "$issue" | cut -d':' -f1)
                action_reason=$(echo "$issue" | cut -d':' -f2)
                action=$(echo "$action_reason" | cut -d'|' -f1)
                reason=$(echo "$action_reason" | cut -d'|' -f2)
                
                echo -e "${BOLD}${CYAN}│${NC}"
                case $action in
                    "ACTUALIZAR")
                        echo -e "${BOLD}${CYAN}│${NC} ${YELLOW}${WARNING} $crd:${NC} $reason"
                        echo -e "${BOLD}${CYAN}│${NC} ${INFO} ${BOLD}Solución:${NC} Actualizar CRDs antes que la aplicación"
                        ;;
                    "CRÍTICO")
                        echo -e "${BOLD}${CYAN}│${NC} ${RED}${ERROR} $crd:${NC} $reason"
                        echo -e "${BOLD}${CYAN}│${NC} ${INFO} ${BOLD}Solución:${NC} Reinstalar CRDs inmediatamente"
                        ;;
                esac
                echo -e "${BOLD}${CYAN}│${NC}"
            fi
        done
    fi
    print_table_footer
fi

# 5. CRDs de Argo Rollouts (información)
echo ""
echo -e "${BOLD}${PURPLE}${INFO} Información de CRDs Argo Rollouts...${NC}"

print_table_header "ARGO ROLLOUTS - INFORMACIÓN"
echo -e "${BOLD}${CYAN}│${NC} ${BOLD}CRD${NC}                     ${BOLD}│${NC} ${BOLD}APIs${NC}         ${BOLD}│${NC} ${BOLD}Fecha Creación${NC}    ${BOLD}│${NC} ${BOLD}Estado${NC}      ${BOLD}${CYAN}│${NC}"
print_table_separator

ROLLOUTS_CRDS=("rollouts.argoproj.io" "analysisruns.argoproj.io" "analysistemplates.argoproj.io" "experiments.argoproj.io" "clusteranalysistemplates.argoproj.io")

ROLLOUTS_DATE=""
for crd in "${ROLLOUTS_CRDS[@]}"; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
        crd_versions=$(kubectl get crd "$crd" -o jsonpath='{.spec.versions[*].name}')
        crd_date=$(kubectl get crd "$crd" -o jsonpath='{.metadata.creationTimestamp}' | cut -d'T' -f1)
        crd_short=$(echo "$crd" | sed 's/.argoproj.io//')
        
        [ -z "$ROLLOUTS_DATE" ] && ROLLOUTS_DATE="$crd_date"
        
        printf "${BOLD}${CYAN}│${NC} ${GREEN}%-23s${NC} ${BOLD}│${NC} ${BLUE}%-12s${NC} ${BOLD}│${NC} ${PURPLE}%-17s${NC} ${BOLD}│${NC} ${GREEN}%-11s${NC} ${BOLD}${CYAN}│${NC}\n" \
               "$crd_short" "$crd_versions" "$crd_date" "Activo"
    fi
done
print_table_footer

# 6. Análisis de sincronización
ARGOCD_DATE=$(kubectl get crd applications.argoproj.io -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null | cut -d'T' -f1)

if [ ! -z "$ARGOCD_DATE" ] && [ ! -z "$ROLLOUTS_DATE" ] && [ "$ARGOCD_DATE" != "$ROLLOUTS_DATE" ]; then
    echo ""
    print_table_header "ANÁLISIS DE SINCRONIZACIÓN"
    echo -e "${BOLD}${CYAN}│${NC} ${WARNING} ${BOLD}Desincronización detectada:${NC}"
    echo -e "${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC} • Argo CD CRDs:      ${YELLOW}$ARGOCD_DATE${NC}"
    echo -e "${BOLD}${CYAN}│${NC} • Argo Rollouts CRDs: ${PURPLE}$ROLLOUTS_DATE${NC}"
    
    # Calcular diferencia de días
    DAYS_DIFF=$(calculate_date_diff "$ARGOCD_DATE" "$ROLLOUTS_DATE")
    
    if [ "$DAYS_DIFF" != "Error" ] && [ ! -z "$DAYS_DIFF" ]; then
        echo -e "${BOLD}${CYAN}│${NC} • Diferencia:         ${RED}$DAYS_DIFF días${NC}"
    else
        echo -e "${BOLD}${CYAN}│${NC} • Diferencia:         ${RED}Significativa${NC}"
    fi
    
    echo -e "${BOLD}${CYAN}│${NC}"
    echo -e "${BOLD}${CYAN}│${NC} ${INFO} ${BOLD}Recomendación:${NC} Sincronizar actualizaciones de ambos componentes"
    echo -e "${BOLD}${CYAN}│${NC} ${INFO} Los CRDs desactualizados pueden causar problemas de compatibilidad"
    print_table_footer
fi

# 7. Resumen ejecutivo y plan de acción
print_header "${CHART} RESUMEN EJECUTIVO"

echo -e "${BOLD}${WHITE}ESTADO GENERAL DEL SISTEMA:${NC}"
if [ ! -z "$IMAGE_VERSION" ]; then
    echo -e "${GREEN}${CHECK} Argo CD detectado: ${BOLD}$IMAGE_VERSION${NC}"
    
    if version_ge "$IMAGE_VERSION" "v2.8.0"; then
        echo -e "${GREEN}${CHECK} Versión actual y bien soportada${NC}"
    elif version_ge "$IMAGE_VERSION" "v2.4.0"; then
        echo -e "${YELLOW}${WARNING} Versión funcional - considerar actualización para nuevas funcionalidades${NC}"
    else
        echo -e "${RED}${ERROR} Versión antigua - actualización fuertemente recomendada${NC}"
    fi
else
    echo -e "${RED}${ERROR} No se pudo determinar la versión de Argo CD${NC}"
fi

if [ $ISSUES_COUNT -gt 0 ]; then
    echo -e "${RED}${ERROR} Se encontraron $ISSUES_COUNT problema(s) de compatibilidad${NC}"
    echo -e "${WARNING} ${BOLD}Acción requerida antes de continuar${NC}"
else
    echo -e "${GREEN}${CHECK} Todos los CRDs son compatibles${NC}"
fi

# Plan de actualización si hay Helm release
if [ ! -z "$HELM_RELEASE" ]; then
    get_update_recommendations "$IMAGE_VERSION" "$CHART_VERSION" "$HELM_RELEASE"
fi

print_header "${ROCKET} VERIFICACIÓN COMPLETADA"

echo -e "${INFO} ${BOLD}Próximos pasos recomendados:${NC}"
echo -e "1. ${CYAN}Ejecutar este script después de cada actualización${NC}"
echo -e "2. ${CYAN}Mantener un calendario de actualizaciones regulares${NC}"
echo -e "3. ${CYAN}Monitorear logs de Argo CD después de cambios${NC}"
echo -e "4. ${CYAN}Considerar automatizar el proceso de actualización de CRDs${NC}"
echo ""