#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
init_command_log "provision-eventgrid"
DEPLOYMENT_NAME="$(deployment_name)"
STORID=$(jq -r '.foundation.storageAccountId' "$ROOT/.provision-outputs.json")
DLQ=$(jq -r '.foundation.dlqContainerName' "$ROOT/.provision-outputs.json")
FLU=$(jq -r '.functions.functionLogUrl' "$ROOT/.provision-outputs.json")
run az account set --subscription "$SUBSCRIPTION_ID"
run_deployment "$RG_NAME" "$DEPLOYMENT_NAME-eventgrid" "$ACTION" --location "$LOCATION" --name "$DEPLOYMENT_NAME-eventgrid" --template-file "$ROOT/infra/eventgrid.bicep" \
  --parameters location="$LOCATION" baseName="$BASE_NAME" environment="$ENVIRONMENT" resourceGroupName="$RG_NAME" \
    storageAccountId="$STORID" dlqContainerName="$DLQ" functionLogUrl="$FLU" deployEventSubscriptions=true

if [[ "$ACTION" == "what-if" ]]; then
  info "Event Grid what-if completed."
else
  success "Event Grid provisioned."
fi
