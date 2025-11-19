#!/bin/bash

# =============================================================================
# Script para generar manifiestos Kubernetes desde templates usando utilidades
# =============================================================================

# ===============================
# Load utilities
# ===============================
set -euo pipefail

# --- Librerías comunes ---
UTILS_DIR="$(cd "/opt/atlassian/pipelines/agent/build/infra-cicd-tools/scripts/" && pwd)"
source "$UTILS_DIR/utils/logging.sh"
source "$UTILS_DIR/utils/error-handling.sh"
source "$UTILS_DIR/utils/utils.sh"

# Inicializar logging y manejo de errores
init_logging
init_error_handling
init_utilities
start_timer

# --- Directorios base ---
BASE_DIR="$(cd "/opt/atlassian/pipelines/agent/build" && pwd)"
K8S_DIR="$BASE_DIR/kubernetes"
OVERLAYS_DIR="$K8S_DIR/overlays"
ENV_FILE="$BASE_DIR/.env"

# --- Determinar entorno según branch ---
BRANCH="${BITBUCKET_BRANCH:-develop}"

case "$BRANCH" in
  main|master)   DEPLOY_ENV="prod";   PREFIX="PROD_";;
  quality|qa) DEPLOY_ENV="qa";    PREFIX="QA_";;
  develop|dev) DEPLOY_ENV="dev";    PREFIX="DEV_";;
  fix*|hotfix*)  DEPLOY_ENV="fix";    PREFIX="FIX_";;
  *)             DEPLOY_ENV="custom"; PREFIX="";;
esac

log_info "📦 Branch detectado: $BRANCH"
log_info "🌎 Entorno seleccionado: $DEPLOY_ENV (prefijo: ${PREFIX:-GLOBAL})"

# --- Validar archivo .env ---
if [ ! -f "$ENV_FILE" ]; then
  log_error "No se encontró archivo .env en la raíz del repo"
  exit 1
fi

# --- Crear overlay si no existe ---
if [ ! -d "$OVERLAYS_DIR/$DEPLOY_ENV" ]; then
  log_warning "Overlay '$DEPLOY_ENV' no existe. Creando a partir de base..."
  mkdir -p "$OVERLAYS_DIR/$DEPLOY_ENV"
  cp -r "$K8S_DIR/base/." "$OVERLAYS_DIR/$DEPLOY_ENV/" 2>/dev/null || true

  # Crear kustomization.yaml mínimo si no existe
  if [ ! -f "$OVERLAYS_DIR/$DEPLOY_ENV/kustomization.yaml" ]; then
    cat <<EOF > "$OVERLAYS_DIR/$DEPLOY_ENV/kustomization.yaml"
bases:
  - ../../base/
patchesStrategicMerge:
  - patch-deployment.yaml
EOF
  fi
fi

VALUES_FILE="$OVERLAYS_DIR/$DEPLOY_ENV/values.env"
> "$VALUES_FILE"

# --- Procesar el .env ---
log_info "🧾 Generando values.env para entorno ${DEPLOY_ENV}..."

while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue

  KEY=$(echo "$line" | cut -d '=' -f1)
  VALUE=$(echo "$line" | cut -d '=' -f2-)

  # Variables globales (sin prefijo)
  if [[ ! "$KEY" =~ ^(DEV_|PROD_|FIX_) ]]; then
    echo "$KEY=$VALUE" >> "$VALUES_FILE"
  fi

  # Variables del entorno específico
  if [[ -n "$PREFIX" && "$KEY" == ${PREFIX}* ]]; then
    NEW_KEY="${KEY#${PREFIX}}"
    echo "$NEW_KEY=$VALUE" >> "$VALUES_FILE"
  fi
done < "$ENV_FILE"

log_success "Archivo values.env generado en: $VALUES_FILE"

# --- Cargar variables para exportar ---
set -a
source "$VALUES_FILE"
set +a

log_info "Variables cargadas: APP_NAME=$APP_NAME | ENVIRONMENT=${ENVIRONMENT:-$DEPLOY_ENV}"

# --- Generar manifiestos con Kustomize ---
OUTPUT_FILE="$K8S_DIR/manifests-${DEPLOY_ENV}.yaml"
log_info "🚀 Generando manifiestos con Kustomize..."
if kustomize build "$OVERLAYS_DIR/$DEPLOY_ENV" > "$OUTPUT_FILE"; then
  log_success "✅ Manifiestos generados: $OUTPUT_FILE"
else
  log_error "Error al generar manifiestos con Kustomize"
  exit 1
fi

# --- Aplicar manifiestos (si AUTO_DEPLOY está activo) ---
if [[ "${AUTO_DEPLOY:-false}" == "true" ]]; then
  log_info "🌍 Aplicando manifiestos al clúster..."
  kubectl apply -k "$OVERLAYS_DIR/$DEPLOY_ENV/"
  log_success "Despliegue completado en entorno: ${DEPLOY_ENV}"
else
  log_warning "AUTO_DEPLOY=false → Solo se generaron manifiestos (sin aplicar)"
fi

log_success "🎉 Proceso completado exitosamente para entorno: $DEPLOY_ENV"