#!/bin/bash

# Verificar que se hayan pasado los parámetros necesarios
if [ $# -lt 2 ]; then
    echo "❌ Uso: $0 <JIRA_ISSUE_KEY> <COMENTARIO>"
    exit 1
fi

ISSUE_KEY="$1"
COMMENT="$2"
USERNAME="$JIRA_USERNAME"
API_TOKEN="$JIRA_API_TOKEN"
BASE_URL="$JIRA_BASE_URL"

echo "💬 Intentando comentar en issue: $ISSUE_KEY"

# Verificar que la clave de issue tenga el formato correcto
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "❌ Formato de clave JIRA inválido: $ISSUE_KEY"
    exit 1
fi

# Probar con diferentes versiones de la API
API_VERSIONS=("2" "3")

for api_version in "${API_VERSIONS[@]}"; do
    echo "🔧 Probando con API v$api_version..."
    
    # Configurar el JSON según la versión de la API
    if [ "$api_version" = "2" ]; then
        JSON_DATA='{"body": "'"$COMMENT"'"}'
    else
        JSON_DATA='{"body": {"type": "doc", "version": 1, "content": [{"type": "paragraph", "content": [{"type": "text", "text": "'"$COMMENT"'"}]}]}}'
    fi
    
    # Hacer la solicitud a la API de JIRA
    response=$(curl -s -w "\n%{http_code}" -u "$USERNAME:$API_TOKEN" -X POST \
        -H "Content-Type: application/json" \
        -d "$JSON_DATA" \
        "$BASE_URL/rest/api/$api_version/issue/$ISSUE_KEY/comment")
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 201 ]; then
        echo "✅ Comentario agregado exitosamente a $ISSUE_KEY (API v$api_version)"
        exit 0
    else
        echo "❌ Error con API v$api_version: Código $http_code"
        if [ "$http_code" -eq 404 ]; then
            echo "   La incidencia $ISSUE_KEY no existe o no tienes permisos"
        elif [ "$http_code" -eq 403 ]; then
            echo "   Permisos insuficientes para comentar en la incidencia"
        elif [ "$http_code" -eq 401 ]; then
            echo "   Error de autenticación con JIRA"
        fi
    fi
done

echo "❌ No se pudo comentar en la incidencia $ISSUE_KEY después de probar todas las versiones de API"
exit 1