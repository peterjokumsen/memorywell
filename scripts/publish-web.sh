#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

step "Preparing environment variables..."
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

step "Acquiring SWA token..."
TOKEN="$(az staticwebapp secrets list --name "web-$BASE_NAME" --resource-group "$RG_NAME" --query properties.apiKey -o tsv)"

cd "$ROOT/web"
step "Building web..."
npm ci
VITE_API_BASE_URL="$API_BASE_URL" VITE_FUNCTIONS_BASE_URL="$FUNCTIONS_BASE_URL" npm run build

step "Installing swa CLI..."
npm i -g @azure/static-web-apps-cli

step "Deploying web (front-end only)..."
swa deploy ./dist --deployment-token "$TOKEN" --env production

BFF_APP_NAME="$(jq -r '.bff.functionAppName // empty' "$OUTPUTS" 2>/dev/null || true)"
if [[ -n "$BFF_APP_NAME" ]]; then
  step "Linking BFF as bring-your-own API..."
  BFF_RESOURCE_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.Web/sites/$BFF_APP_NAME"
  az staticwebapp backends link \
    --name "web-$BASE_NAME" \
    --resource-group "$RG_NAME" \
    --backend-resource-id "$BFF_RESOURCE_ID" \
    --backend-region "$(az staticwebapp show --name "web-$BASE_NAME" --resource-group "$RG_NAME" --query location -o tsv)"
fi

echo "Published web"
