#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

step "Preparing..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUTS="${1:-}"

if [[ -z "$OUTPUTS" ]]; then
  OUTPUTS="$ROOT/.provision-outputs.json"
fi

step "Acquiring SWA token..."
TOKEN="$(az staticwebapp secrets list --name "web-$BASE_NAME" --resource-group "$RG_NAME" --query properties.apiKey -o tsv)"

cd "$ROOT/web"
step "Building web..."
npm ci
npm run build

step "Deploying web (front-end only)..."
npx -y @azure/static-web-apps-cli deploy ./dist --deployment-token "$TOKEN" --env production

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
