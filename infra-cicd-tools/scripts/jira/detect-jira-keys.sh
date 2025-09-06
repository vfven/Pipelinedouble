#!/bin/bash

echo "=== DETECTANDO CLAVES JIRA EN COMMITS ==="

# Cargar script de conexión
source ./scripts/check-jira-connection.sh

# Extraer claves JIRA del último commit
COMMIT_MESSAGE=$(git log --pretty=format:"%s" -1)
JIRA_KEYS=$(echo "$COMMIT_MESSAGE" | grep -oE '[A-Z]+-[0-9]+' | sort | uniq)

echo "📝 Mensaje del commit: $COMMIT_MESSAGE"
echo "🔑 Claves JIRA encontradas: $JIRA_KEYS"

if [ -z "$JIRA_KEYS" ]; then
    echo "ℹ️  No se encontraron claves JIRA en el mensaje de commit"
    exit 0
fi

# Contador de éxitos y errores
SUCCESS_COUNT=0
ERROR_COUNT=0

echo ""
echo "🚀 Procesando incidencias JIRA..."

for issue_key in $JIRA_KEYS; do
    echo ""
    echo "📋 Procesando incidencia: $issue_key"
    
    # Crear mensaje personalizado para cada issue
    COMMENT="Se ha implementado un cambio relacionado con este issue. Commit: $COMMIT_MESSAGE [Bitbucket Pipeline: $BITBUCKET_BUILD_NUMBER]"
    
    # Ejecutar script de comentario
    if ./scripts/comment-jira.sh "$issue_key" "$COMMENT"; then
        echo "✅ Comentario agregado exitosamente a $issue_key"
        ((SUCCESS_COUNT++))
    else
        echo "❌ Error al comentar en $issue_key"
        ((ERROR_COUNT++))
    fi
done

echo ""
echo "📊 Resumen:"
echo "   ✅ Comentarios exitosos: $SUCCESS_COUNT"
echo "   ❌ Comentarios fallidos: $ERROR_COUNT"

if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi