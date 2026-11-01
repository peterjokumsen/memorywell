#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
ACTION="${1:-create}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
init_command_log "provision-functions"
DEPLOYMENT_NAME="$(deployment_name)"
FID=$(jq -r '.foundation.identityId' "$ROOT/.provision-outputs.json")
FCL=$(jq -r '.foundation.identityClientId' "$ROOT/.provision-outputs.json")
STOR=$(jq -r '.foundation.storageAccountName' "$ROOT/.provision-outputs.json")
DEP=$(jq -r '.foundation.deploymentContainerName' "$ROOT/.provision-outputs.json")
AICS=$(jq -r '.foundation.appInsightsConnectionString' "$ROOT/.provision-outputs.json")
CE=$(jq -r '.databases.cosmosAccountEndpoint' "$ROOT/.provision-outputs.json")
run az account set --subscription "$SUBSCRIPTION_ID"
run_deployment "$RG_NAME" "$DEPLOYMENT_NAME-functions" "$ACTION" --location "$LOCATION" --name "$DEPLOYMENT_NAME-functions" --template-file "$ROOT/infra/functions.bicep" \
  --parameters location="$LOCATION" baseName="$BASE_NAME" environment="$ENVIRONMENT" resourceGroupName="$RG_NAME" \
    storageAccountName="$STOR" deploymentContainerName="$DEP" cosmosAccountEndpoint="$CE" \
    identityId="$FID" identityClientId="$FCL" appInsightsConnectionString="$AICS"

if [[ "$ACTION" == "what-if" ]]; then
  info "Functions what-if completed."
else
  OUT="$(fetch_deployment_outputs "$DEPLOYMENT_NAME-functions" "[properties.outputs.functionAppName.value, properties.outputs.functionAppFqdn.value, properties.outputs.functionLogUrl.value, properties.outputs.serviceBusNamespaceName.value]" 4)"
  IFS=$'\t' read -r FAN FAF FLU SBN <<< "$OUT"
  jq --arg fan "$FAN" --arg faf "$FAF" --arg flu "$FLU" --arg sbn "$SBN" '.functions={functionAppName:$fan,functionAppFqdn:$faf,functionLogUrl:$flu,serviceBusNamespaceName:$sbn}' "$ROOT/.provision-outputs.json" > "$ROOT/.provision-outputs.json.tmp" && mv "$ROOT/.provision-outputs.json.tmp" "$ROOT/.provision-outputs.json"
  success "Functions provisioned."
fi
