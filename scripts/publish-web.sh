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
npm ci
npm run build

TOKEN="$(az staticwebapp secrets list --name "$APP" --resource-group "$RG" --query properties.apiKey -o tsv)"
npx --yes @azure/static-web-apps-cli deploy ./dist --deployment-token "$TOKEN" --env production
echo "Published web to $APP"
