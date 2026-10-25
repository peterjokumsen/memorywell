#!/usr/bin/env bash
set -euo pipefail

export AZURE_IDENTITY_DISABLE_BROKER=true
export AZURE_IDENTITY_DISABLED_CREDENTIALS="VisualStudioCodeCredential,SharedTokenCacheCredential,InteractiveBrowserCredential"

mkdir -p /tmp/azurite
azurite --silent --location /tmp/azurite >/tmp/azurite/azurite.log 2>&1 &
AZURITE_PID=$!
trap 'kill $AZURITE_PID 2>/dev/null' EXIT

func start
