#!/bin/bash

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
# Validación del entorno
# =============================================================================
if [[ -z "${DEPLOY_ENV:-}" ]]; then
    log_error "❌ DEPLOY_ENV no está cargado."
    exit 1
fi

log_info "Usando DEPLOY_ENV: $DEPLOY_ENV"

# =============================================================================
# Crear overlay temporal limpio
# =============================================================================
OVERLAY_ENV_DIR="$OVERLAYS_DIR/$DEPLOY_ENV"

rm -rf "$OVERLAY_ENV_DIR"   # LIMPIEZA
mkdir -p "$OVERLAY_ENV_DIR"

log_info "Copiando base limpia..."
cp -r "$K8S_REPO_DIR/base/"* "$OVERLAY_ENV_DIR"

# ---------------------------------------------------------------------------
# Asegurar un kustomization.yaml válido
# ---------------------------------------------------------------------------
KFILE="$OVERLAY_ENV_DIR/kustomization.yaml"

log_info "Reescribiendo kustomization.yaml..."

cat > "$KFILE" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${K8S_NAMESPACE}

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - configmap.yaml
  - secret.yaml

images:
  - name: hola-mundobase
    newName: ${IMAGE_FULL}
    newTag: "${IMAGE_TAG}"
EOF

# =============================================================================
# Generar values.env
# =============================================================================
VALUES_FILE="$OVERLAY_ENV_DIR/values.env"
> "$VALUES_FILE"

while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  KEY=$(echo "$line" | cut -d '=' -f1)
  VALUE=$(echo "$line" | cut -d '=' -f2-)
  echo "$KEY=$VALUE" >> "$VALUES_FILE"
done < "$ENV_FILE"

set -a
source "$VALUES_FILE"
set +a

# =============================================================================
# Cargar ECR metadata
# =============================================================================
ECR_INFO_FILE="$BASE_DIR/ecr-push-info.txt"
if [[ -f "$ECR_INFO_FILE" ]]; then
    log_info "Usando metadata de imagen desde ecr-push-info.txt"
    source "$ECR_INFO_FILE"
fi

export IMAGE_FULL="${ECR_IMAGE_URI:-${APP_NAME}:${IMAGE_TAG}}"

log_info "Imagen final para despliegue: $IMAGE_FULL"

# =============================================================================
# Render templates
# =============================================================================
RENDER_DIR="$RENDER_DIR_BASE/$DEPLOY_ENV"
mkdir -p "$RENDER_DIR"

log_info "Renderizando YAMLs..."
for f in "$OVERLAY_ENV_DIR"/*.yaml; do
  [[ "$f" == *"values.env"* ]] && continue
  envsubst < "$f" > "$RENDER_DIR/$(basename "$f")"
done

# =============================================================================
# Kustomize build
# =============================================================================
FINAL_MANIFEST_DIR="$MANIFESTS_DIR/$DEPLOY_ENV"
mkdir -p "$FINAL_MANIFEST_DIR"

log_info "Ejecutando kustomize build..."
kustomize build "$RENDER_DIR" > "$FINAL_MANIFEST_DIR/all.yaml"

# =============================================================================
# Dividir recursos
# =============================================================================
log_info "Separando recursos... "
cd "$FINAL_MANIFEST_DIR"
csplit -f res- -b "%02d.yaml" all.yaml '/^---$/' '{*}' || true
rm all.yaml

# Renombrado
for f in res*.yaml; do
  KIND=$(grep -m1 "^kind:" "$f" | awk '{print tolower($2)}')
  case "$KIND" in
    deployment) mv "$f" deployment.yaml ;;
    service) mv "$f" service.yaml ;;
    ingress) mv "$f" ingress.yaml ;;
    configmap) mv "$f" configmap.yaml ;;
    secret) mv "$f" secret.yaml ;;
    horizontalpodautoscaler) mv "$f" hpa.yaml ;;
    *) mv "$f" "${KIND}.yaml" ;;
  esac
done

log_success "Manifiestos generados correctamente."

# =============================================================================
# ZIP artifacts
# =============================================================================
EXPORT_DIR="$BASE_DIR/artifacts/k8s/$DEPLOY_ENV"
mkdir -p "$EXPORT_DIR"
cp -r "$FINAL_MANIFEST_DIR"/* "$EXPORT_DIR"/

ZIP_FILE="$BASE_DIR/artifacts/k8s-manifests-$DEPLOY_ENV.zip"
zip -j "$ZIP_FILE" "$EXPORT_DIR"/*

log_success "ZIP listo: $ZIP_FILE"