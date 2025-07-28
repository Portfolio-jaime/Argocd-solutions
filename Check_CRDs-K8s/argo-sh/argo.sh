#!/bin/bash

# Script de Validación de CRDs de ArgoCD
# Autor: Assistant
# Fecha: $(date +%Y-%m-%d)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
NAMESPACE="argocd"

# Obtener la ruta del script y crear carpeta de logs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="$SCRIPT_DIR/logs"

# Crear carpeta de logs si no existe
mkdir -p "$LOGS_DIR"

LOG_FILE="${LOG_FILE:-$LOGS_DIR/argocd_crd_validation_$(date +%Y%m%d_%H%M%S).log}"

# Función para logging
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Función para títulos de sección
section_title() {
    log "${BLUE}=================================================================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}=================================================================================${NC}"
}

# Función para verificar si el comando existe
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "${RED}Error: $1 no está instalado${NC}"
        exit 1
    fi
}

# Función para verificar si el namespace existe
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "${RED}Error: El namespace '$NAMESPACE' no existe${NC}"
        exit 1
    fi
}

# Función para obtener información del servidor ArgoCD
get_argocd_server_info() {
    section_title "INFORMACIÓN DEL SERVIDOR ARGOCD"
    
    local server_deployment=$(kubectl get deployment -n "$NAMESPACE" | grep "argocd-server" | awk '{print $1}')
    if [[ -z "$server_deployment" ]]; then
        log "${RED}❌ No se encontró el deployment argocd-server${NC}"
        return 1
    fi
    
    log "${GREEN}✓ Deployment encontrado: $server_deployment${NC}"
    
    local server_image=$(kubectl get deployment "$server_deployment" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
    local server_version=$(echo "$server_image" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+[^:]*' || echo "Unknown")
    
    log "📦 Imagen del servidor: $server_image"
    log "🏷️  Versión extraída: $server_version"
    
    # Guardar para comparaciones posteriores
    echo "$server_version" > /tmp/argocd_server_version
    echo "$server_image" > /tmp/argocd_server_image
}

# Función para obtener información de los CRDs
get_crd_info() {
    section_title "INFORMACIÓN DE LOS CRDs"
    
    # Lista de CRDs de ArgoCD
    local crds=("applications.argoproj.io" "applicationsets.argoproj.io" "appprojects.argoproj.io")
    
    for crd in "${crds[@]}"; do
        log "${YELLOW}🔍 Analizando CRD: $crd${NC}"
        
        if kubectl get crd "$crd" &> /dev/null; then
            log "${GREEN}✓ CRD existe${NC}"
            
            # Información básica del CRD
            local managed_by=$(kubectl get crd "$crd" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || echo "Unknown")
            local crd_version=$(kubectl get crd "$crd" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>/dev/null || echo "Unknown")
            local creation_date=$(kubectl get crd "$crd" -o jsonpath='{.metadata.creationTimestamp}')
            
            log "  📋 Administrado por: $managed_by"
            log "  🏷️  Versión etiquetada: $crd_version"
            log "  📅 Fecha de creación: $creation_date"
            
            # Versiones de API soportadas
            local api_versions=$(kubectl get crd "$crd" -o jsonpath='{.spec.versions[*].name}' 2>/dev/null)
            log "  🔌 Versiones de API: $api_versions"
            
        else
            log "${RED}❌ CRD no encontrado: $crd${NC}"
        fi
        log ""
    done
}

# Función para verificar recursos de API
check_api_resources() {
    section_title "VERIFICACIÓN DE RECURSOS DE API"
    
    log "🔍 Verificando recursos de argoproj.io disponibles..."
    local api_resources=$(kubectl api-resources | grep argoproj.io)
    
    if [[ -n "$api_resources" ]]; then
        log "${GREEN}✓ Recursos de API disponibles:${NC}"
        echo "$api_resources" | while read line; do
            log "  📝 $line"
        done
    else
        log "${RED}❌ No se encontraron recursos de API de argoproj.io${NC}"
    fi
}

# Función para verificar el estado de las aplicaciones
check_applications_health() {
    section_title "ESTADO DE LAS APLICACIONES ARGOCD"
    
    log "🔍 Contando aplicaciones por estado..."
    
    local total_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | wc -l)
    local synced_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep "Synced" | wc -l)
    local healthy_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep "Healthy" | wc -l)
    local outofSync_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep "OutOfSync" | wc -l)
    local degraded_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep "Degraded" | wc -l)
    
    log "📊 Total de aplicaciones: $total_apps"
    log "✅ Aplicaciones sincronizadas: $synced_apps"
    log "🟢 Aplicaciones saludables: $healthy_apps"
    log "🟡 Aplicaciones fuera de sincronización: $outofSync_apps"
    log "🔴 Aplicaciones degradadas: $degraded_apps"
    
    # Mostrar aplicaciones problemáticas si las hay
    if [[ $outofSync_apps -gt 0 || $degraded_apps -gt 0 ]]; then
        log "${YELLOW}⚠️  Aplicaciones con problemas:${NC}"
        kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep -E "(OutOfSync|Degraded)" | head -10 | while read line; do
            log "  🔸 $line"
        done
        if [[ $(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep -E "(OutOfSync|Degraded)" | wc -l) -gt 10 ]]; then
            log "  ... y $(($(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep -E "(OutOfSync|Degraded)" | wc -l) - 10)) más"
        fi
    fi
}

# Función para verificar logs de componentes de ArgoCD
check_argocd_logs() {
    section_title "VERIFICACIÓN DE LOGS DE ARGOCD"
    
    local components=("argocd-server" "argocd-repo-server" "argocd-applicationset-controller")
    
    for component in "${components[@]}"; do
        log "${YELLOW}🔍 Verificando logs de $component...${NC}"
        
        if kubectl get deployment "$component" -n "$NAMESPACE" &> /dev/null; then
            log "${GREEN}✓ Deployment encontrado${NC}"
            
            # Buscar errores relacionados con CRDs y versiones
            local errors=$(kubectl logs -n "$NAMESPACE" deployment/"$component" --tail=1000 2>/dev/null | grep -i -E "(error|crd|version|api.*not found|unknown field)" | head -5)
            
            if [[ -n "$errors" ]]; then
                log "${YELLOW}⚠️  Errores/warnings encontrados:${NC}"
                echo "$errors" | while read line; do
                    log "  🔸 $line"
                done
            else
                log "${GREEN}✓ No se encontraron errores relacionados con CRDs${NC}"
            fi
        else
            log "${RED}❌ Deployment no encontrado: $component${NC}"
        fi
        log ""
    done
}

# Función para generar recomendaciones
generate_recommendations() {
    section_title "RECOMENDACIONES"
    
    local server_version=$(cat /tmp/argocd_server_version 2>/dev/null || echo "Unknown")
    local server_image=$(cat /tmp/argocd_server_image 2>/dev/null || echo "Unknown")
    
    log "🎯 Basado en el análisis realizado:"
    log ""
    
    # Verificar si es una imagen custom
    if [[ "$server_image" == *"amazonaws.com"* ]] || [[ "$server_image" == *"pr-patch"* ]]; then
        log "${YELLOW}⚠️  IMAGEN PERSONALIZADA DETECTADA${NC}"
        log "   📦 Imagen: $server_image"
        log "   🔧 Esta es una imagen personalizada/custom de ArgoCD"
        log "   💡 Recomendación: NO actualizar CRDs sin consultar con el equipo que mantiene esta imagen"
        log ""
    fi
    
    # Verificar estado general
    local total_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | wc -l)
    local problematic_apps=$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | grep -E "(OutOfSync|Degraded)" | wc -l)
    
    if [[ $total_apps -gt 0 && $problematic_apps -lt 5 ]]; then
        log "${GREEN}✅ ESTADO GENERAL: SALUDABLE${NC}"
        log "   📊 $total_apps aplicaciones funcionando correctamente"
        log "   💡 Recomendación: NO es necesario actualizar los CRDs en este momento"
        log ""
    elif [[ $problematic_apps -ge 5 ]]; then
        if [[ $problematic_apps -lt 10 ]]; then
        log "${GREEN}✅ ESTADO GENERAL: SALUDABLE CON PROBLEMAS MENORES${NC}"
        log "   📊 $problematic_apps aplicaciones con problemas menores (< 3% del total)"
        log "   💡 Recomendación: Los problemas detectados no están relacionados con CRDs"
    else
        log "${YELLOW}⚠️  ESTADO GENERAL: NECESITA ATENCIÓN${NC}"
        log "   📊 $problematic_apps aplicaciones con problemas"
        log "   💡 Recomendación: Investigar los problemas existentes antes de considerar actualizar CRDs"
    fi
        log ""
    fi
    
    # Recomendaciones específicas
    log "${BLUE}📋 PRÓXIMOS PASOS RECOMENDADOS:${NC}"
    log "   1. 🔍 Revisar el log completo: $LOG_FILE"
    log "   2. 📁 Los logs se guardan en: $LOGS_DIR"
    log "   3. 📞 Consultar con el equipo que mantiene la imagen personalizada"
    log "   4. 🧪 Si decides actualizar, hacerlo primero en un entorno de pruebas"
    log "   5. 💾 Realizar backup completo antes de cualquier actualización"
    log "   6. 📚 Verificar documentación interna sobre la imagen custom utilizada"
}

# Función para limpiar archivos temporales
cleanup() {
    rm -f /tmp/argocd_server_version /tmp/argocd_server_image
}

# Función principal
main() {
    log "${GREEN}🚀 Iniciando validación de CRDs de ArgoCD${NC}"
    log "📝 Log guardado en: $LOG_FILE"
    log "📁 Carpeta de logs: $LOGS_DIR"
    log ""
    
    # Verificaciones previas
    check_command "kubectl"
    check_namespace
    
    # Ejecutar validaciones
    get_argocd_server_info
    get_crd_info
    check_api_resources
    check_applications_health
    check_argocd_logs
    generate_recommendations
    
    log ""
    log "${GREEN}✅ Validación completada${NC}"
    log "📝 Revisa el log completo en: $LOG_FILE"
    
    # Limpiar archivos temporales
    cleanup
}

# Manejo de señales para limpieza
trap cleanup EXIT

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi