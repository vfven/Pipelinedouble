#!/bin/bash

echo "=== VALIDANDO CONEXIÓN CON JIRA ==="

# Verificar que las variables de entorno estén configuradas
if [ -z "$JIRA_BASE_URL" ] || [ -z "$JIRA_USERNAME" ] || [ -z "$JIRA_API_TOKEN" ]; then
    echo "❌ ERROR: Variables de entorno no configuradas"
    echo "   Configura JIRA_BASE_URL, JIRA_USERNAME y JIRA_API_TOKEN en las variables del repositorio"
    exit 1
fi

echo "✅ Variables de entorno configuradas correctamente"
echo "   JIRA_BASE_URL: $JIRA_BASE_URL"
echo "   JIRA_USERNAME: $JIRA_USERNAME"
echo "   JIRA_API_TOKEN: ${JIRA_API_TOKEN:0:4}******" # Mostrar solo primeros 4 caracteres

# Probar diferentes endpoints de la API de JIRA
endpoints=(
    "/rest/api/2/myself"
    "/rest/api/3/myself"
    "/rest/api/2/application-properties"
    "/status"
)

echo ""
echo "🔍 Probando conectividad con JIRA..."

for endpoint in "${endpoints[@]}"; do
    echo ""
    echo "Probando endpoint: $endpoint"
    
    response=$(curl -s -w "\n%{http_code}" -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        -X GET "$JIRA_BASE_URL$endpoint")
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    echo "Código HTTP: $http_code"
    
    if [ "$http_code" -eq 200 ]; then
        echo "✅ Conexión exitosa"
        # Si es el endpoint de myself, mostrar información del usuario
        if [[ "$endpoint" == *"myself"* ]]; then
            user_displayName=$(echo "$response_body" | grep -o '"displayName":"[^"]*' | cut -d'"' -f4)
            user_email=$(echo "$response_body" | grep -o '"emailAddress":"[^"]*' | cut -d'"' -f4)
            echo "   Usuario: $user_displayName ($user_email)"
        fi
        break
    else
        echo "❌ Error en endpoint $endpoint"
    fi
done

# Verificar si al menos un endpoint funcionó
if [ "$http_code" -ne 200 ]; then
    echo ""
    echo "❌ ERROR: No se pudo establecer conexión con JIRA"
    echo "   Verifica:"
    echo "   1. La URL de JIRA: $JIRA_BASE_URL"
    echo "   2. Las credenciales de API"
    echo "   3. Los permisos del usuario"
    echo "   4. La conectividad de red"
    exit 1
fi

echo ""
echo "✅ Conexión con JIRA validada correctamente"
exit 0