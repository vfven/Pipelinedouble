#!/bin/bash

# =============================================================================
# Build Docker Image Script with Advanced Logging and Error Handling
# =============================================================================

set -Eeuo pipefail

# Load utilities
source infra-cicd-tools/scripts/utils/logging.sh
source infra-cicd-tools/scripts/utils/error-handling.sh
source infra-cicd-tools/scripts/utils/utils.sh

# Initialize
init_utilities
start_timer

log_section "Docker Image Build Process"
log_environment

# Parse command line arguments
parse_args "$@"

# Set default values
APP_NAME="${APP_NAME:-${BITBUCKET_REPO_SLUG:-unknown-app}}"
IMAGE_TAG="${APP_VERSION:-${BITBUCKET_BUILD_NUMBER:-latest}}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile}"
DOCKER_CONTEXT="${DOCKER_CONTEXT:-.}"

log_step "1" "Validating configuration"
log_info "$APP_VERSION"
validate_not_empty "APP_NAME"
validate_not_empty "IMAGE_TAG"
validate_file_exists "$DOCKERFILE_PATH" "Dockerfile not found at: $DOCKERFILE_PATH"
validate_directory_exists "$DOCKER_CONTEXT" "Docker context directory not found: $DOCKER_CONTEXT"
validate_docker_config

log_step "2" "Building Docker image"
log_info "Application: $APP_NAME"
log_info "Image Tag: $IMAGE_TAG"
log_info "Dockerfile: $DOCKERFILE_PATH"
log_info "Build Context: $DOCKER_CONTEXT"

log_command "docker build \
  -t \"$APP_NAME:$IMAGE_TAG\" \
  -f \"$DOCKERFILE_PATH\" \
  \"$DOCKER_CONTEXT\""

log_step "3" "Saving build metadata"
safe_exec "echo \"APP_NAME=$APP_NAME\" > docker-image-info.txt"
safe_exec "echo \"IMAGE_TAG=$IMAGE_TAG\" >> docker-image-info.txt"
safe_exec "echo \"IMAGE_REPO=$APP_NAME\" >> docker-image-info.txt"

log_step "4" "Verifying built image"
log_command "docker images | grep \"$APP_NAME\""
log_command "docker save $APP_NAME:$IMAGE_TAG -o docker.tar"

log_duration "Docker build"
log_success "Docker image built successfully: $APP_NAME:$IMAGE_TAG"
