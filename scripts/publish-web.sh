#!/usr/bin/env bash
set -euo pipefail

RG="${1:-}"
APP="${2:-}"

if [[ -z "$RG" || -z "$APP" ]]; then
  echo "Usage: $0 <resource-group> <web-app-name>"
  exit 1
fi

cd "$(dirname "$0")/../web"
npm ci
npm run build

cd dist
zip -r /tmp/web.zip . >/dev/null
az webapp deploy --resource-group "$RG" --name "$APP" --src-path /tmp/web.zip --type zip
echo "Published web to $APP"
EOF
chmod +x scripts/publish-web.sh
bash -n scripts/publish-web.sh && echo ok
