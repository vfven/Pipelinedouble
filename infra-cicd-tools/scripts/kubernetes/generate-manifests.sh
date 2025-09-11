#!/bin/bash

# =============================================================================
# Script para generar manifiestos Kubernetes desde templates usando utilidades
# =============================================================================

set -euo pipefail

# ===============================
# Load utilities
# ===============================
source infra-cicd-tools/scripts/utils/logging.sh
source infra-cicd-tools/scripts/utils/error-handling.sh
source infra-cicd-tools/scripts/utils/utils.sh

# Inicializar logging y manejo de errores
init_logging
init_error_handling
init_utilities
start_timer

log_section "GENERACIÓN DE MANIFIESTOS KUBERNETES"

# ===============================
# Directorios y variables
# ===============================
TEMPLATES_DIR="infra-cicd-tools/templates/kubernetes-manifiest"
OUTPUT_DIR="./kubernetes-manifests/generated/${APP_NAME:-hola-mundo}-${ENVIRONMENT:-development}"

# Validar que el directorio de templates exista
validate_directory_exists "$TEMPLATES_DIR" "Templates directory not found: $TEMPLATES_DIR"

# Crear y validar el directorio de output
mkdir -p "$OUTPUT_DIR"
validate_directory_exists "$OUTPUT_DIR" "Failed to create or access output directory: $OUTPUT_DIR"

#export APP_NAME="${APP_NAME:-hola-mundo}"
#export DEPLOY_ENV="${DEPLOY_ENV:-development}"
#export IMAGE_TAG="${IMAGE_TAG:-latest}"
export IMAGE_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
#export APP_PORT="${APP_PORT:-3000}"
#export REPLICAS="${REPLICAS:-1}"
#export VERSION="${VERSION:-$IMAGE_TAG}"
#export NAMESPACE="${NAMESPACE:-$DEPLOY_ENV}"

log_info "App: $APP_NAME | Env: $ENVIRONMENT | Image: $IMAGE_REPO:$IMAGE_TAG | Namespace: $K8S_NAMESPACE"

# ===============================
# Función para procesar templates
# ===============================
process_template() {
    local template_file="$1"
    local output_file="$2"

    if [ -f "$template_file" ]; then
        safe_exec "envsubst < \"$template_file\" > \"$output_file\"" "Error generando template: $template_file"
        log_success "Generado: $(basename "$output_file")"
    else
        log_warning "Template no encontrado: $template_file"
    fi
}

# ===============================
# Generar todos los manifiestos
# ===============================
log_subsection "Procesando templates de Kubernetes..."

for template in "$TEMPLATES_DIR"/*.tpl; do
    if [ -f "$template" ]; then
        filename=$(basename "$template" .tpl)
        process_template "$template" "$OUTPUT_DIR/$filename"
    fi
done

# ===============================
# Generar kustomization.yaml
# ===============================
log_subsection "Generando kustomization.yaml"

cat > "$OUTPUT_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - secret.yaml
  - hpa.yaml
  - ingress.yaml

namespace: $K8S_NAMESPACE

commonLabels:
  app: $APP_NAME
  environment: $ENVIRONMENT
  version: $IMAGE_TAG
EOF

log_success "Kustomization generado en: $OUTPUT_DIR"
log_info "Archivos generados:"
ls -la "$OUTPUT_DIR"

log_duration "Generación de manifiestos"