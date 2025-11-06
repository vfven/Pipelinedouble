#!/bin/bash
# jira-debug-search.sh

set -Eeuo pipefail

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$UTILS_DIR/utils/logging.sh"

echo "=== JIRA Search Debug ==="

# Configuración
JIRA_PROJECT_KEY="${JIRA_PROJECT_KEY:-JD}"
APP_VERSION="${APP_VERSION:-1.0.0}"
REPO_NAME="${REPO_NAME:-app-source-code}"
RELEASE_NAME="$REPO_NAME v$APP_VERSION"

echo "Project: $JIRA_PROJECT_KEY"
echo "Release: $RELEASE_NAME"
echo ""

# 1. Verificar que el release existe
echo "1. Checking if release exists..."
release_response=$(curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
    -X GET "$JIRA_BASE_URL/rest/api/3/project/$JIRA_PROJECT_KEY/versions")

echo "Release search response:"
echo "$release_response" | jq . 2>/dev/null || echo "$release_response"

# Buscar nuestro release específico
release_id=$(echo "$release_response" | jq -r ".[] | select(.name == \"$RELEASE_NAME\") | .id" 2>/dev/null || echo "")
if [ -n "$release_id" ]; then
    echo "✅ Release found: $RELEASE_NAME (ID: $release_id)"
else
    echo "❌ Release NOT found: $RELEASE_NAME"
fi

echo ""
echo "2. Searching for ALL subtasks in release..."
jql_query="project = \"$JIRA_PROJECT_KEY\" AND fixVersion = \"$RELEASE_NAME\" AND issuetype = Sub-task ORDER BY created DESC"
encoded_jql=$(echo "$jql_query" | jq -s -R -r @uri)

response=$(curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
    -X GET \
    "$JIRA_BASE_URL/rest/api/3/search/jql?jql=$encoded_jql&maxResults=50&fields=key,summary,issuetype,parent")

total_results=$(echo "$response" | jq -r '.total // 0')
echo "Total subtasks in release: $total_results"

if [ "$total_results" -gt 0 ]; then
    echo "Subtasks found:"
    echo "$response" | jq -r '.issues[] | "  \(.key) - \(.fields.summary) (Parent: \(.fields.parent.key))"'
else
    echo "No subtasks found in release"
fi

echo ""
echo "3. Searching for ALL issues with 'Security' in name..."
jql_query="project = \"$JIRA_PROJECT_KEY\" AND text ~ \"Security\" ORDER BY created DESC"
encoded_jql=$(echo "$jql_query" | jq -s -R -r @uri)

response=$(curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
    -X GET \
    "$JIRA_BASE_URL/rest/api/3/search/jql?jql=$encoded_jql&maxResults=20&fields=key,summary,issuetype")

total_results=$(echo "$response" | jq -r '.total // 0')
echo "Total 'Security' issues: $total_results"

if [ "$total_results" -gt 0 ]; then
    echo "Security-related issues:"
    echo "$response" | jq -r '.issues[] | "  \(.key) - \(.fields.summary) (\(.fields.issuetype.name))"'
fi

echo ""
echo "4. Testing exact name search..."
jql_query="project = \"$JIRA_PROJECT_KEY\" AND summary ~ \"Security Vulnerability Scan\""
encoded_jql=$(echo "$jql_query" | jq -s -R -r @uri)

response=$(curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
    -X GET \
    "$JIRA_BASE_URL/rest/api/3/search/jql?jql=$encoded_jql&maxResults=5&fields=key,summary,issuetype")

total_results=$(echo "$response" | jq -r '.total // 0')
echo "Exact name search results: $total_results"
echo "$response" | jq . 2>/dev/null || echo "$response"