#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
ACTION="${1:-create}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
init_command_log "provision-databases"
DEPLOYMENT_NAME="$(deployment_name)"
F=$(jq -r '.foundation.identityPrincipalId' "$ROOT/.provision-outputs.json")
run az account set --subscription "$SUBSCRIPTION_ID"
run az deployment sub create --location "$LOCATION" --name "$DEPLOYMENT_NAME-databases" --template-file "$ROOT/infra/databases.bicep" \
  --parameters location="$LOCATION" baseName="$BASE_NAME" environment="$ENVIRONMENT" resourceGroupName="$RG_NAME" \
    keyVaultName="$VAULT_NAME" cosmosAccountName="$COSMOS_ACCOUNT_NAME" cosmosDatabase="$COSMOS_DATABASE" \
    postgresKeyName="${POSTGRES_KEY_NAME:-postgres}" postgresClientIp="${CLIENT_IP:-}" \
    postgresAdministratorPassword="${POSTGRES_ADMIN_PASSWORD:-}" developerPrincipalObjectId="${DEVELOPER_OBJECT_ID:-}" \
    identityPrincipalIds="['$F']"
OUT="$(fetch_deployment_outputs "$DEPLOYMENT_NAME-databases" "[properties.outputs.keyVaultUri.value, properties.outputs.cosmosAccountEndpoint.value, properties.outputs.cosmosDatabaseName.value, properties.outputs.postgresServerName.value]" 5)"
IFS=$'\t' read -r KV CE CD PS <<< "$OUT"
jq --arg kv "$KV" --arg ce "$CE" --arg cd "$CD" --arg ps "$PS" '.databases={keyVaultUri:$kv,cosmosAccountEndpoint:$ce,cosmosDatabaseName:$cd,postgresServerName:$ps}' "$ROOT/.provision-outputs.json" > "$ROOT/.provision-outputs.json.tmp" && mv "$ROOT/.provision-outputs.json.tmp" "$ROOT/.provision-outputs.json"
success "Databases provisioned."
