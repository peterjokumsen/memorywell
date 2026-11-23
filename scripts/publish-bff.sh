#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

step "Preparing environment..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUTS="${1:-$ROOT/.provision-outputs.json}"

if [[ -n "$OUTPUTS" && -f "$OUTPUTS" ]]; then
  BFF_APP_NAME="$(jq -r '.bff.functionAppName' "$OUTPUTS")"
else
  BFF_APP_NAME="${BFF_FUNCTION_APP_NAME:-}"
fi

if [[ -z "$BFF_APP_NAME" ]]; then
  echo "BFF function app name must be provided via outputs or BFF_FUNCTION_APP_NAME" >&2
  exit 1
fi

step "Publishing BFF to $BFF_APP_NAME..."
cd "$ROOT/bff"
func azure functionapp publish "$BFF_APP_NAME" --python
echo "Published BFF"
