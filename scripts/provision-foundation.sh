#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
ACTION="${1:-create}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
init_command_log "provision-foundation"
DEPLOYMENT_NAME="$(deployment_name)"

run az account set --subscription "$SUBSCRIPTION_ID"

# Guard against redeploying while a previous teardown is still draining.
# `teardown.sh` deletes the RG with --no-wait and the managed environment
# takes a while to delete, so the RG lingers in Deleting state; a Bicep
# sub-deployment issued in that window fails. Fail fast instead.
step "Checking resource group $RG_NAME state..."
if RG_STATE=$(run_hide_stderr az group show --name "$RG_NAME" --query properties.provisioningState -o tsv); then
  success "Resource group $RG_NAME exists (provisioningState: $RG_STATE)."
  if [[ "$RG_STATE" == "Deleting" ]]; then
    error "Resource group $RG_NAME is still deleting (managed environment teardown is slow)."
    error "Wait until it is gone, then retry. Check with:"
    error "  az group show --name \"$RG_NAME\" --query properties.provisioningState -o tsv"
    exit 1
  fi
else
  info "Resource group $RG_NAME does not exist (expected on first deploy)."
  RG_STATE="absent"
fi

# Create the group when missing, ahead of the role grant below. main.bicep
# declares it `existing`, so this script is the only thing that creates it —
# which is the point: the Key Vault Secrets Officer grant must target the group
# before the deployment writes connection strings into the vault. Tags are
# deliberately NOT passed here; infra/modules/rgtags.bicep applies them during
# the deployment so the tag values stay owned by Bicep.
step "Ensuring resource group $RG_NAME exists..."
if [[ "$RG_STATE" == "absent" ]]; then
  run az group create --name "$RG_NAME" --location "$LOCATION"
  RG_STATE="Created"
fi

# Writing a secret into Key Vault needs Secrets Officer; the in-template
# Key Vault Secrets User role is read-only and is the API identity's, not the
# deployer's. Scoped to the group rather than the vault so the grant outlives
# teardown.sh --purge-vault. az role assignment create is idempotent, so this is
# a no-op on repeat runs.
step "Granting Key Vault write access in $RG_NAME..."
KV_WRITER_ROLE="Key Vault Secrets Officer"
RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}"

# The pipeline principal for non-dev environments. Unset for local study runs;
# prod should use a distinct SP with no dev privileges, scoped to its own group.
# --assignee-object-id + --assignee-principal-type rather than --assignee: the
# latter resolves the id through Microsoft Graph, which a CI service principal
# may not be allowed to query. Passing the id directly also sidesteps the
# principal-type inference that misfires while a new principal propagates.
if [[ -n "${DEPLOYMENT_SP_OBJECT_ID:-}" ]]; then
  run az role assignment create --role "$KV_WRITER_ROLE" \
    --assignee-object-id "$DEPLOYMENT_SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal --scope "$RG_SCOPE"
else
  debug "DEPLOYMENT_SP_OBJECT_ID not set; skipping the pipeline principal grant."
fi

# Whoever is logged in. Not fatal when absent: a service-principal deploy has no
# user to resolve and is covered by DEPLOYMENT_SP_OBJECT_ID instead.
if HUMAN_OID=$(run_hide_stderr az ad signed-in-user show --query id -o tsv) && [[ -n "$HUMAN_OID" ]]; then
  run az role assignment create --role "$KV_WRITER_ROLE" \
    --assignee-object-id "$HUMAN_OID" \
    --assignee-principal-type User --scope "$RG_SCOPE"
else
  warn "  No signed-in user found; skipping the interactive principal grant."
fi

run_deployment "$RG_NAME" "$DEPLOYMENT_NAME-foundation" "$ACTION" --location "$LOCATION" --name "$DEPLOYMENT_NAME-foundation" --template-file "$ROOT/infra/foundation.bicep" \
  --parameters location="$LOCATION" baseName="$BASE_NAME" environment="$ENVIRONMENT" resourceGroupName="$RG_NAME" \
    sharedResourceGroupName="$SHARED_RG_NAME" acrName="$(registry_name)" developerPrincipalObjectId="${DEVELOPER_OBJECT_ID:-}"

if [[ "$ACTION" == "what-if" ]]; then
  info "Foundation what-if completed."
else
  OUT="$(fetch_deployment_outputs "$DEPLOYMENT_NAME-foundation" "[properties.outputs.identityId.value, properties.outputs.identityClientId.value, properties.outputs.identityPrincipalId.value, properties.outputs.storageAccountName.value, properties.outputs.storageAccountId.value, properties.outputs.deploymentContainerName.value, properties.outputs.bffDeploymentContainerName.value, properties.outputs.dlqContainerName.value, properties.outputs.monitorCustomerId.value, properties.outputs.monitorWorkspaceId.value, properties.outputs.monitorApiVersion.value, properties.outputs.appInsightsConnectionString.value]" 12)"
  IFS=$'\t' read -r ID CLIENT PRINCIPAL STOR STORID DEP BFFDEP DLQ MONC MONW MONA AICS <<< "$OUT"
  jq -n --arg id "$ID" --arg client "$CLIENT" --arg principal "$PRINCIPAL" --arg stor "$STOR" --arg storid "$STORID" --arg dep "$DEP" --arg bffdep "$BFFDEP" --arg dlq "$DLQ" --arg monc "$MONC" --arg monw "$MONW" --arg mona "$MONA" --arg aics "$AICS" '{foundation:{identityId:$id,identityClientId:$client,identityPrincipalId:$principal,storageAccountName:$stor,storageAccountId:$storid,deploymentContainerName:$dep,bffDeploymentContainerName:$bffdep,dlqContainerName:$dlq,monitorCustomerId:$monc,monitorWorkspaceId:$monw,monitorApiVersion:$mona,appInsightsConnectionString:$aics}}' > "$ROOT/.provision-outputs.json"
  success "Foundation provisioned."
fi
