#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RG="${1:-}"
APP="${2:-}"

if [[ -z "$RG" || -z "$APP" ]]; then
  echo "Usage: $0 <resource-group> <static-web-app-name>"
  exit 1
fi

cd "$ROOT/web"

API_BASE_URL="${3:-${VITE_API_BASE_URL:-}}"
FUNCTIONS_BASE_URL="${4:-${VITE_FUNCTIONS_BASE_URL:-}}"

if [[ -z "$API_BASE_URL" || -z "$FUNCTIONS_BASE_URL" ]]; then
  echo "API and Functions base URLs must be provided (args 3/4 or env vars)" >&2
  exit 1
fi

cat > public/config.json <<EOF
{
  "apiBaseUrl": "$API_BASE_URL",
  "functionsBaseUrl": "$FUNCTIONS_BASE_URL"
}
EOF

npm ci
npm run build

TOKEN="$(az staticwebapp secrets list --name "$APP" --resource-group "$RG" --query properties.apiKey -o tsv)"
npx --yes @azure/static-web-apps-cli deploy ./dist --deployment-token "$TOKEN" --env production
echo "Published web to $APP"
