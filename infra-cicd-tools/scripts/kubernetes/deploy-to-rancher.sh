#!/bin/bash

# =============================================================================
# Script para despliegue en Rancher desde Bitbucket
# =============================================================================

set -euo pipefail

echo "=== DESPLEGANDO EN RANCHER ==="

# Variables
APP_NAME="${1:-$APP_NAME}"
ENVIRONMENT="${2:-development}"
IMAGE_TAG="${3:-latest}"
MANIFESTS_DIR="./kubernetes-manifests/generated/${APP_NAME}-${ENVIRONMENT}"

# Usar contexto de Rancher (si está configurado)
if [ -n "${KUBE_CONTEXT:-}" ]; then
    kubectl config use-context "$KUBE_CONTEXT"
fi

# Validar
if [ ! -d "$MANIFESTS_DIR" ]; then
    echo "❌ No se encontraron manifiestos en: $MANIFESTS_DIR"
    exit 1
fi

# Desplegar
echo "🚀 Desplegando $APP_NAME ($IMAGE_TAG) en Rancher ($ENVIRONMENT)..."
kubectl apply -f "$MANIFESTS_DIR/" --record

# Esperar rollout
echo "⏳ Esperando por el rollout..."
kubectl rollout status deployment/"$APP_NAME" -n "$ENVIRONMENT" --timeout=300s

echo "✅ Despliegue en Rancher completado!"