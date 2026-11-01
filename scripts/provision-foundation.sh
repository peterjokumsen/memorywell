#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
ACTION="${1:-create}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
init_command_log "provision-foundation"
DEPLOYMENT_NAME="$(deployment_name)"
run az account set --subscription "$SUBSCRIPTION_ID"
run az deployment sub create --location "$LOCATION" --name "$DEPLOYMENT_NAME-foundation" --template-file "$ROOT/infra/foundation.bicep" \
  --parameters location="$LOCATION" baseName="$BASE_NAME" environment="$ENVIRONMENT" resourceGroupName="$RG_NAME" \
    sharedResourceGroupName="$SHARED_RG_NAME" acrName="$(registry_name)" developerPrincipalObjectId="${DEVELOPER_OBJECT_ID:-}"
OUT="$(fetch_deployment_outputs "$DEPLOYMENT_NAME-foundation" "[properties.outputs.identityId.value, properties.outputs.identityClientId.value, properties.outputs.identityPrincipalId.value, properties.outputs.storageAccountName.value, properties.outputs.storageAccountId.value, properties.outputs.deploymentContainerName.value, properties.outputs.dlqContainerName.value, properties.outputs.monitorCustomerId.value, properties.outputs.monitorWorkspaceId.value, properties.outputs.monitorApiVersion.value, properties.outputs.appInsightsConnectionString.value]" 5)"
IFS=$'\t' read -r ID CLIENT PRINCIPAL STOR STORID DEP DLQ MONC MONW MONA AICS <<< "$OUT"
jq -n --arg id "$ID" --arg client "$CLIENT" --arg principal "$PRINCIPAL" --arg stor "$STOR" --arg storid "$STORID" --arg dep "$DEP" --arg dlq "$DLQ" --arg monc "$MONC" --arg monw "$MONW" --arg mona "$MONA" --arg aics "$AICS" '{foundation:{identityId:$id,identityClientId:$client,identityPrincipalId:$principal,storageAccountName:$stor,storageAccountId:$storid,deploymentContainerName:$dep,dlqContainerName:$dlq,monitorCustomerId:$monc,monitorWorkspaceId:$monw,monitorApiVersion:$mona,appInsightsConnectionString:$aics}}' > "$ROOT/.provision-outputs.json"
success "Foundation provisioned."
