#!/bin/bash

# =============================================================================
# Tenable Scan Image
# =============================================================================

set -Eeuo pipefail

# Load utilities
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../utils" && pwd)"
source "$UTILS_DIR/logging.sh"
source "$UTILS_DIR/error-handling.sh"
source "$UTILS_DIR/utils.sh"

# Initialize
init_utilities
start_timer

log_section "Validating values"
log_environment

# Parse command line arguments
parse_args "$@"

# Set default values
APP_NAME="${APP_NAME:-${BITBUCKET_REPO_SLUG:-unknown-app}}"
IMAGE_TAG="${IMAGE_TAG:-${BITBUCKET_BUILD_NUMBER:-latest}}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile}"
DOCKER_CONTEXT="${DOCKER_CONTEXT:-.}"

log_step "1" "Validating configuration"
validate_not_empty "APP_NAME"
validate_not_empty "IMAGE_TAG"
validate_file_exists "$DOCKERFILE_PATH" "Dockerfile not found at: $DOCKERFILE_PATH"
validate_directory_exists "$DOCKER_CONTEXT" "Docker context directory not found: $DOCKER_CONTEXT"
validate_docker_config

log_step "2" "Image properties"
log_info "Application: $APP_NAME"
log_info "Image Tag: $IMAGE_TAG"

log_step "3" "Not empty tenable values"
validate_not_empty "VAULT_NAMESPACE"
validate_not_empty "ROLE_ID"
validate_not_empty "SECRET_ID"
validate_not_empty "VAULT_ADDR"
validate_not_empty "TENABLE_API_URL"

log_success "Environments correct"

VAULT_TOKEN=$(curl -s \
          --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
          --request POST \
          --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
          $VAULT_ADDR/v1/auth/approle/login | jq -r '.auth.client_token')
       
RESPONSE=$(curl -s \
          --header "X-Vault-Token: $VAULT_TOKEN" \
          --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
          $VAULT_ADDR/v1/kv/tenable/data/api-token)

TENABLE_API_TOKEN=$(echo $RESPONSE | jq -r '.data.data.TENABLE_API_TOKEN')

log_subsection "Escaneando Imagen creada"

log_command "docker run \
  --workdir /tmp/tenable \
  --volume $BITBUCKET_CLONE_DIR:/tmp/tenable \
  --pull=always tenable/cloud-security-scanner:latest \
  container-image scan --name vulnerables/web-dvwa \
  --api-token $TENABLE_API_TOKEN \
  --api-url $TENABLE_API_URL \
  --fail-on-min-severity critical"

#--env-file .env \

log_duration "Docker build"
log_success "Tenable scan successfully: $APP_NAME:$IMAGE_TAG"