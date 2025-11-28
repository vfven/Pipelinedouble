#!/bin/bash

# =============================================================================
# Script Genera manifiestos
# =============================================================================

set -euo pipefail

# =============================================================================
# Load utilities
# =============================================================================
UTILS_DIR="$(cd "/opt/atlassian/pipelines/agent/build/infra-cicd-tools/scripts/" && pwd)"
source "$UTILS_DIR/utils/logging.sh"
source "$UTILS_DIR/utils/error-handling.sh"
source "$UTILS_DIR/utils/utils.sh"

init_logging
init_error_handling
init_utilities
start_timer

# =============================================================================
# Directorios del repo y temporales
# =============================================================================
BASE_DIR="$(cd "/opt/atlassian/pipelines/agent/build" && pwd)"
K8S_REPO_DIR="$BASE_DIR/kubernetes"
ENV_FILE="$BASE_DIR/.env"

K8S_TMP_DIR="/tmp/kubernetes"
OVERLAYS_DIR="$K8S_TMP_DIR/overlays"
RENDER_DIR_BASE="$K8S_TMP_DIR/rendered"
MANIFESTS_DIR="$K8S_TMP_DIR/manifests"

mkdir -p "$OVERLAYS_DIR" "$RENDER_DIR_BASE" "$MANIFESTS_DIR"

# =============================================================================
# Validación del entorno (DEPLOY_ENV + PREFIX)
# Estas variables DEBEN venir desde load-env.sh
# =============================================================================
if [[ -z "${DEPLOY_ENV:-}" ]]; then
    log_error "❌ DEPLOY_ENV no está cargado. ¿Olvidaste ejecutar load-env.sh primero?"
    exit 1
fi

if [[ -z "${PREFIX:-}" ]]; then
    log_warning "⚠️ PREFIX vacío. Se cargarán solo variables globales."
fi

log_info "Usando DEPLOY_ENV: $DEPLOY_ENV (prefijo: '${PREFIX:-GLOBAL}')"

# Validación del archivo .env
if [ ! -f "$ENV_FILE" ]; then
  log_error "❌ No se encontró archivo .env en la raíz del repo"
  exit 1
fi

# =============================================================================
# Crear overlay temporal en /tmp
# =============================================================================
OVERLAY_ENV_DIR="$OVERLAYS_DIR/$DEPLOY_ENV"
mkdir -p "$OVERLAY_ENV_DIR"

if [ ! -d "$OVERLAY_ENV_DIR/base_copiada" ]; then
  log_warning "Overlay '$DEPLOY_ENV' no existe en TMP. Copiando base..."
  cp -r "$K8S_REPO_DIR/base/." "$OVERLAY_ENV_DIR/"
  touch "$OVERLAY_ENV_DIR/base_copiada"

  # 🔥 Asegurar namespace en kustomization.yaml
  if grep -q "^namespace:" "$OVERLAY_ENV_DIR/kustomization.yaml"; then
      sed -i "s|^namespace:.*|namespace: ${K8S_NAMESPACE}|g" "$OVERLAY_ENV_DIR/kustomization.yaml"
  else
      sed -i "1inamespace: ${K8S_NAMESPACE}" "$OVERLAY_ENV_DIR/kustomization.yaml"
  fi
fi

# =============================================================================
# Generar values.env
# =============================================================================
VALUES_FILE="$OVERLAY_ENV_DIR/values.env"
> "$VALUES_FILE"

log_info "Generando values.env para entorno ${DEPLOY_ENV}..."

while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue

  KEY=$(echo "$line" | cut -d '=' -f1)
  VALUE=$(echo "$line" | cut -d '=' -f2-)

  # Globales
  if [[ ! "$KEY" =~ ^(DEV_|QA_|PROD_|FIX_|STAGE_) ]]; then
    echo "$KEY=$VALUE" >> "$VALUES_FILE"
  fi

  # Variables del entorno
  if [[ -n "$PREFIX" && "$KEY" == ${PREFIX}* ]]; then
    NEW_KEY="${KEY#${PREFIX}}"
    echo "$NEW_KEY=$VALUE" >> "$VALUES_FILE"
  fi

done < "$ENV_FILE"

# Exportar al ambiente
set -a
source "$VALUES_FILE"
set +a

log_success "Archivo values.env generado: $VALUES_FILE"
log_info "Variables cargadas: APP_NAME=$APP_NAME | ENVIRONMENT=${ENVIRONMENT:-$DEPLOY_ENV}"

# =============================================================================
# Cargar información de la imagen ECR
# =============================================================================
ECR_INFO_FILE="$BASE_DIR/ecr-push-info.txt"

if [[ -f "$ECR_INFO_FILE" ]]; then
    log_info "Cargando metadata de imagen desde ecr-push-info.txt..."
    source "$ECR_INFO_FILE"
else
    log_warning "⚠️ No se encontró ecr-push-info.txt. Se usarán valores por defecto."
fi

# =============================================================================
# Imagen final para los manifiestos
# =============================================================================
if [[ -n "${ECR_IMAGE_URI:-}" ]]; then
    export IMAGE_FULL="$ECR_IMAGE_URI"
    log_info "Imagen final desde ECR: $IMAGE_FULL"
else
    export IMAGE_FULL="${ECR_REPO_NAME:-$APP_NAME}:${IMAGE_TAG:-latest}"
    log_warning "⚠️ ECR_IMAGE_URI no encontrado, usando imagen local: $IMAGE_FULL"
fi

# =============================================================================
# Render (envsubst)
# =============================================================================
RENDER_DIR="$RENDER_DIR_BASE/$DEPLOY_ENV"
mkdir -p "$RENDER_DIR"

log_info "Renderizando templates con envsubst..."

cp -r "$OVERLAY_ENV_DIR/"* "$RENDER_DIR"/

for f in $(find "$RENDER_DIR" -type f -name "*.yaml"); do
  envsubst < "$f" > "${f}.tmp"
  mv "${f}.tmp" "$f"
done

log_success "✔ Variables sustituidas correctamente"

# =============================================================================
# Generar archivo único -> luego dividirlo
# =============================================================================
FINAL_MANIFEST_DIR="$MANIFESTS_DIR/$DEPLOY_ENV"
mkdir -p "$FINAL_MANIFEST_DIR"

log_info "Ejecutando kustomize build..."
kustomize build "$RENDER_DIR" > "$FINAL_MANIFEST_DIR/all.yaml"

log_info "Separando recursos..."
cd "$FINAL_MANIFEST_DIR"

csplit -f resource- -b "%02d.yaml" all.yaml '/^---$/' '{*}' || true
rm all.yaml

# =============================================================================
# Renombrar cada recurso según su Kind
# =============================================================================
log_info "Renombrando recursos por Kind..."

for f in resource-*.yaml; do
    KIND=$(grep -m1 "^kind:" "$f" | awk '{print tolower($2)}')

    case "$KIND" in
        deployment)   NEW_NAME="deployment.yaml" ;;
        service)      NEW_NAME="service.yaml" ;;
        ingress)      NEW_NAME="ingress.yaml" ;;
        configmap)    NEW_NAME="configmap.yaml" ;;
        secret)       NEW_NAME="secret.yaml" ;;
        horizontalpodautoscaler|hpa) NEW_NAME="hpa.yaml" ;;
        *) NEW_NAME="${KIND}.yaml" ;;
    esac

    mv "$f" "$NEW_NAME"
    log_info " → $NEW_NAME"
done

log_success "Manifiestos generados correctamente en: $FINAL_MANIFEST_DIR"

# =============================================================================
# AUTO DEPLOY
# =============================================================================
if [[ "${AUTO_DEPLOY:-false}" == "true" ]]; then
  log_info "Aplicando despliegue..."
  kubectl apply -k "$RENDER_DIR"
  log_success "Despliegue aplicado"
else
  log_warning "AUTO_DEPLOY=false → No se aplicaron cambios"
fi

log_success "Proceso completado exitosamente para entorno: $DEPLOY_ENV"

# =============================================================================
# Exportar ZIP a artifacts/
# =============================================================================
EXPORT_DIR="$BASE_DIR/artifacts/k8s/$DEPLOY_ENV"
mkdir -p "$EXPORT_DIR"

log_info "Copiando manifiestos a artifacts..."
cp -r "$FINAL_MANIFEST_DIR"/* "$EXPORT_DIR"/

ZIP_FILE="$BASE_DIR/artifacts/k8s-manifests-$DEPLOY_ENV.zip"

log_info "Creando ZIP..."
zip -j "$ZIP_FILE" "$EXPORT_DIR"/*

log_success "ZIP listo: $ZIP_FILE"