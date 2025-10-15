#!/bin/bash

# =============================================================================
# Load enviroment values
# =============================================================================

set -euo pipefail

# === Importar librerías comunes ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/error-handling.sh"
source "$SCRIPT_DIR/utils.sh"

# === Variables iniciales ===
ENVIRONMENT=${1:-development}
ENV_FILE=".env"

# === Validación de archivo .env ===
if [ ! -f "$ENV_FILE" ]; then
  log_error "No se encontró el archivo $ENV_FILE"
  exit 1
fi

log_info "📦 Cargando variables para ambiente: $ENVIRONMENT"

# === Determinar prefijo según el ambiente ===
case $ENVIRONMENT in
  development|dev)
    PREFIX="DEV_"
    ;;
  production|prod)
    PREFIX="PROD_"
    ;;
  staging|stage)
    PREFIX="STAGE_"
    ;;
  *)
    PREFIX=""
    log_warn "Ambiente no reconocido, cargando solo variables comunes"
    ;;
esac

# === Procesar archivo .env ===
rm -f export_vars.sh
touch export_vars.sh

# 1. Exportar variables globales (sin prefijo)
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ ]] && continue   # comentarios
  [[ -z "$line" ]] && continue         # líneas vacías

  KEY=$(echo "$line" | cut -d '=' -f1)
  VALUE=$(echo "$line" | cut -d '=' -f2-)

  # Si no tiene prefijo conocido, lo tomamos como GLOBAL
  if [[ ! "$KEY" =~ ^(DEV_|PROD_|STAGE_) ]]; then
    export "$KEY"="$VALUE"
    echo "export $KEY=\"$VALUE\"" >> export_vars.sh
  fi
done < "$ENV_FILE"

# 2. Exportar variables del ambiente actual (según prefijo)
if [[ -n "$PREFIX" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    KEY=$(echo "$line" | cut -d '=' -f1)
    VALUE=$(echo "$line" | cut -d '=' -f2-)

    if [[ "$KEY" == ${PREFIX}* ]]; then
      export "${KEY#${PREFIX}}"="$VALUE"
      echo "export ${KEY#${PREFIX}}=\"$VALUE\"" >> export_vars.sh
    fi
  done < "$ENV_FILE"
fi

VAULT_TOKEN=$(curl -s \
          --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
          --request POST \
          --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
          $VAULT_ADDR/v1/auth/approle/login | jq -r '.auth.client_token')
       
RESPONSE=$(curl -s \
          --header "X-Vault-Token: $VAULT_TOKEN" \
          --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
          $VAULT_ADDR/v1/kv/tenable/data/api-token)

#TENABLE_API_TOKEN=$(echo $RESPONSE | jq -r '.data.data.TENABLE_API_TOKEN')
#echo "export TENABLE_API_TOKEN=\"$TENABLE_API_TOKEN\"" >> export_vars.sh

# === Confirmación ===
log_success "Variables cargadas correctamente"
head -n 20 export_vars.sh | sed 's/^/  [OK] /'
