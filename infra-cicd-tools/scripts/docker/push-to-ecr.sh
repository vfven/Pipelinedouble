#!/bin/bash

# =============================================================================
# Push to ECR Script with Advanced Logging and Error Handling
# =============================================================================

set -Eeuo pipefail

# Load utilities
source infra-cicd-tools/scripts/utils/logging.sh
source infra-cicd-tools/scripts/utils/error-handling.sh
source infra-cicd-tools/scripts/utils/utils.sh

# Initialize
init_utilities
start_timer

log_section "ECR Push Process"
log_environment

# Parse command line arguments
parse_args "$@"

log_step "1" "Loading image information"
if [ -f docker-image-info.txt ]; then
    source docker-image-info.txt
else
    APP_NAME="${APP_NAME:-${BITBUCKET_REPO_SLUG}}"
    IMAGE_TAG="${IMAGE_TAG:-${BITBUCKET_BUILD_NUMBER:-latest}}"
    IMAGE_REPO="${IMAGE_REPO:-$APP_NAME}"
    log_warning "docker-image-info.txt not found, using default values"
fi

log_step "2" "Validating AWS configuration"
validate_required_vars AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_ACCOUNT_ID
validate_aws_config

# Set defaults
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO_NAME="${ECR_REPO_NAME:-$APP_NAME}"

log_info "AWS Account: $AWS_ACCOUNT_ID"
log_info "AWS Region: $AWS_REGION"
log_info "ECR Repository: $ECR_REPO_NAME"
log_info "Image: $APP_NAME:$IMAGE_TAG"

log_step "3" "Logging into ECR"
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
log_command "aws ecr get-login-password --region \"$AWS_REGION\" | \
  docker login --username AWS --password-stdin \"$ECR_REGISTRY\""

log_step "4" "Checking/Creating ECR repository"
if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    log_info "Creating ECR repository: $ECR_REPO_NAME"
    log_command "aws ecr create-repository --repository-name \"$ECR_REPO_NAME\" --region \"$AWS_REGION\""
else
    log_info "ECR repository already exists: $ECR_REPO_NAME"
fi

log_step "5" "Tagging and pushing image"
FULL_IMAGE_NAME="$ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG"
log_command "docker tag \"$APP_NAME:$IMAGE_TAG\" \"$FULL_IMAGE_NAME\""
log_command "docker push \"$FULL_IMAGE_NAME\""

log_step "6" "Saving push metadata"
safe_exec "echo \"ECR_IMAGE_URI=$FULL_IMAGE_NAME\" > ecr-push-info.txt"
safe_exec "echo \"ECR_REPO_NAME=$ECR_REPO_NAME\" >> ecr-push-info.txt"
safe_exec "echo \"IMAGE_TAG=$IMAGE_TAG\" >> ecr-push-info.txt"

log_duration "ECR push"
log_success "Image successfully pushed to ECR: $FULL_IMAGE_NAME"