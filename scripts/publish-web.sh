#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUTS="${1:-}"

if [[ -n "$OUTPUTS" && -f "$OUTPUTS" ]]; then
  API_BASE_URL="$(jq -r '.apiBaseUrl.value // .apiBaseUrl // empty' "$OUTPUTS")"
  FUNCTIONS_BASE_URL="$(jq -r '.functionsBaseUrl.value // .functionsBaseUrl // empty' "$OUTPUTS")"
else
  API_BASE_URL="${VITE_API_BASE_URL:-}"
  FUNCTIONS_BASE_URL="${VITE_FUNCTIONS_BASE_URL:-}"
fi

if [[ -z "$API_BASE_URL" || -z "$FUNCTIONS_BASE_URL" ]]; then
  echo "API and Functions base URLs must be provided via outputs or env vars" >&2
  exit 1
fi

TOKEN="${SWA_DEPLOYMENT_TOKEN:-}"
if [[ -z "$TOKEN" ]]; then
  echo "SWA_DEPLOYMENT_TOKEN must be set" >&2
  exit 1
fi

cd "$ROOT/web"
npm ci
VITE_API_BASE_URL="$API_BASE_URL" VITE_FUNCTIONS_BASE_URL="$FUNCTIONS_BASE_URL" npm run build

npx --yes @azure/static-web-apps-cli deploy ./dist --deployment-token "$TOKEN" --env production
echo "Published web"
