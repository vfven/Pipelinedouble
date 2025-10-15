#!/bin/bash

# =============================================================================
# Hasicorp vault
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

log_section "Connect to HASHICORP for TOKEN"
log_environment

# Parse command line arguments
parse_args "$@"

# =============================================================================
# Connect to HASHICORP for TOKEN
# =============================================================================

log_step "1" "Validating configuration"
validate_not_empty "VAULT_NAMESPACE"
validate_not_empty "ROLE_ID"
validate_not_empty "SECRET_ID"
validate_not_empty "VAULT_ADDR"

log_subsection "1 Verificando Contenido"
VAULT_TOKEN=$(curl -s \
          --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
          --request POST \
          --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
          $VAULT_ADDR/v1/auth/approle/login | jq -r '.auth.client_token')
       
RESPONSE=$(curl -s \
          --header "X-Vault-Token: $VAULT_TOKEN" \
          --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
          $VAULT_ADDR/v1/kv/tenable/data/api-token)


log_subsection "Se extraen valores"

echo "$RESPONSE"
#echo "export TENABLE_API_TOKEN=\"$(echo $RESPONSE | jq -r '.data.data.TENABLE_API_TOKEN')\"" >> export_vars.sh

TENABLE_API_TOKEN_B=$(echo $RESPONSE | jq -r '.data.data.TENABLE_API_TOKEN')
#echo "$TENABLE_API_TOKEN_B" | gpg --symmetric --cipher-algo AES256 -o secret.pgp
#echo "$TENABLE_API_TOKEN_B" | openssl enc -aes-256-cbc -a -salt -pass pass:"$BITBUCKET_SECRET_PASSPHRASE" -out secret.enc

log_success "Valores obtenidos"

log_duration "Hashicorp Vars"
#log_success "Tenable scan successfully: $APP_NAME:$IMAGE_TAG"
