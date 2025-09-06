#!/bin/bash

# =============================================================================
# Script para generar manifiestos Kubernetes desde templates
# =============================================================================

# Script optimizado para Bitbucket Pipelines
set -euo pipefail

echo "=== GENERANDO MANIFIESTOS KUBERNETES ==="

# Directorios
TEMPLATES_DIR="./kubernetes-manifests/templates"
OUTPUT_DIR="./kubernetes-manifests/generated/${APP_NAME}-${DEPLOY_ENV}"
mkdir -p "$OUTPUT_DIR"

# Variables requeridas
export APP_NAME="${APP_NAME:-hola-mundo}"
export DEPLOY_ENV="${DEPLOY_ENV:-development}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
export IMAGE_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
export APP_PORT="${APP_PORT:-3000}"
export REPLICAS="${REPLICAS:-1}"
export VERSION="${VERSION:-$IMAGE_TAG}"
export NAMESPACE="${NAMESPACE:-$DEPLOY_ENV}"

# Función para procesar templates
process_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ -f "$template_file" ]; then
        envsubst < "$template_file" > "$output_file"
        echo "✅ Generado: $(basename "$output_file")"
    else
        echo "⚠️  Template no encontrado: $template_file"
    fi
}

# Generar todos los manifiestos
echo "📦 Generando manifiestos para $APP_NAME en $DEPLOY_ENV..."

for template in "$TEMPLATES_DIR"/*.tpl; do
    if [ -f "$template" ]; then
        filename=$(basename "$template" .tpl)
        process_template "$template" "$OUTPUT_DIR/$filename.yaml"
    fi
done

# Generar kustomization.yaml
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

namespace: $NAMESPACE

commonLabels:
  app: $APP_NAME
  environment: $DEPLOY_ENV
  version: $VERSION
EOF

echo "✅ Manifiestos generados en: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"