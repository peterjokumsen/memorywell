#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
ACTION="${1:-create}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
init_command_log "provision-containerapp"
DEPLOYMENT_NAME="$(deployment_name)"

FID=$(jq -r '.foundation.identityId' "$ROOT/.provision-outputs.json")
FCL=$(jq -r '.foundation.identityClientId' "$ROOT/.provision-outputs.json")
FPR=$(jq -r '.foundation.identityPrincipalId' "$ROOT/.provision-outputs.json")
MC=$(jq -r '.foundation.monitorCustomerId' "$ROOT/.provision-outputs.json")
MW=$(jq -r '.foundation.monitorWorkspaceId' "$ROOT/.provision-outputs.json")
MA=$(jq -r '.foundation.monitorApiVersion' "$ROOT/.provision-outputs.json")
AICS=$(jq -r '.foundation.appInsightsConnectionString' "$ROOT/.provision-outputs.json")
ACR=$(registry_name)
LS=$(login_server)
KV=$(jq -r '.databases.keyVaultUri' "$ROOT/.provision-outputs.json")
CE=$(jq -r '.databases.cosmosAccountEndpoint' "$ROOT/.provision-outputs.json")
CD=$(jq -r '.databases.cosmosDatabaseName' "$ROOT/.provision-outputs.json")

run az account set --subscription "$SUBSCRIPTION_ID"
run_deployment "$RG_NAME" "$DEPLOYMENT_NAME-containerapp" "$ACTION" --location "$LOCATION" --name "$DEPLOYMENT_NAME-containerapp" --template-file "$ROOT/infra/containerapp.bicep" \
  --parameters location="$LOCATION" baseName="$BASE_NAME" environment="$ENVIRONMENT" resourceGroupName="$RG_NAME" \
    acrLoginServer="$LS" identityId="$FID" identityClientId="$FCL" identityPrincipalId="$FPR" \
    monitorCustomerId="$MC" monitorWorkspaceId="$MW" monitorApiVersion="$MA" appInsightsConnectionString="$AICS" \
    cosmosDatabase="$CD" cosmosEndpoint="$CE" keyVaultUri="$KV" postgresConnKey="${POSTGRES_KEY_NAME:-postgres}" containerImage="${IMAGE:-mcr.microsoft.com/azuredocs/containerapps-helloworld:latest}"

if [[ "$ACTION" == "what-if" ]]; then
  info "Container app what-if completed."
else
  OUT="$(fetch_deployment_outputs "$DEPLOYMENT_NAME-containerapp" "[properties.outputs.appName.value, properties.outputs.fqdn.value, properties.outputs.webAppUrl.value, properties.outputs.managedEnvironmentId.value]" 4)"
  IFS=$'\t' read -r APP FQDN WEB ME <<< "$OUT"
  jq --arg app "$APP" --arg fqdn "$FQDN" --arg web "$WEB" --arg me "$ME" '.containerapp={appName:$app,fqdn:$fqdn,webAppUrl:$web,managedEnvironmentId:$me}' "$ROOT/.provision-outputs.json" > "$ROOT/.provision-outputs.json.tmp" && mv "$ROOT/.provision-outputs.json.tmp" "$ROOT/.provision-outputs.json"
  success "Container app provisioned."
fi
