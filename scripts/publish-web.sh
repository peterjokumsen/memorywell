#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUTS="${1:-}"

if [[ -z "$OUTPUTS" ]]; then
  OUTPUTS="$ROOT/.provision-outputs.json"
fi

if [[ -n "$OUTPUTS" && -f "$OUTPUTS" ]]; then
  API_BASE_URL="https://$(jq -r '.containerapp.fqdn' "$OUTPUTS")"
  FUNCTIONS_BASE_URL="https://$(jq -r '.functions.functionAppFqdn' "$OUTPUTS")"
else
  API_BASE_URL="${VITE_API_BASE_URL:-}"
  FUNCTIONS_BASE_URL="${VITE_FUNCTIONS_BASE_URL:-}"
fi

if [[ -z "$API_BASE_URL" || -z "$FUNCTIONS_BASE_URL" ]]; then
  echo "API and Functions base URLs must be provided via outputs or env vars" >&2
  exit 1
fi

TOKEN="$(az staticwebapp secrets list --name "web-$BASE_NAME" --resource-group "$RG_NAME" --query properties.apiKey -o tsv)"

cd "$ROOT/web"
step "Build web..."
npm ci
VITE_API_BASE_URL="$API_BASE_URL" VITE_FUNCTIONS_BASE_URL="$FUNCTIONS_BASE_URL" npm run build

step "Deploy web..."
npx --yes @azure/static-web-apps-cli deploy ./dist --deployment-token "$TOKEN" --env production
echo "Published web"
