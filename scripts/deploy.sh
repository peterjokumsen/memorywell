#!/usr/bin/env bash
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Parse arguments
ACTION="create"
BICEP_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --bicep-only)
      BICEP_ONLY=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--action create|what-if] [--bicep-only]"
      echo "  --action ACTION      Deployment action: create (default) or what-if"
      echo "  --bicep-only         Stop after Bicep deployment; skip Docker build, container app update, and health checks"
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      echo "Usage: $0 [--action create|what-if] [--bicep-only]" >&2
      exit 1
      ;;
  esac
done

if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  error "$ACTION is not a valid action"
  echo "Usage: $0 [--action create|what-if] [--bicep-only]" >&2
  exit 1
fi

if [[ "$BICEP_ONLY" == "1" && "$ACTION" == "what-if" ]]; then
  error "--bicep-only is not compatible with --action what-if"
  exit 1
fi

init_command_log "deploy"

# Get client IP and mint the timestamped deployment name + image tag
# (lazy: sourcing common.sh alone reserves nothing; see deployment_name in common.sh).
DEPLOYMENT_NAME="$(deployment_name)"
IMAGE_TAG="$(image_tag)"
CLIENT_IP="$(curl -s https://ifconfig.me)"
export DEPLOYMENT_NAME IMAGE_TAG CLIENT_IP

# Set the subscription context for Azure CLI commands
run az account set --subscription "$SUBSCRIPTION_ID"

# The ACR lives in the shared resource group and must exist before the env
# deployment: main.bicep declares it as `existing`, so a missing registry fails
# the Bicep deployment partway through (after the env RG is created). On
# `create`, deploy it automatically so one script call provisions everything;
# `what-if` never creates anything, so it still fails fast with the fix.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
step "Checking shared resource group $SHARED_RG_NAME..."
if ! SHARED_RG_STATE=$(run_hide_stderr az group show --name "$SHARED_RG_NAME" --query properties.provisioningState -o tsv); then
  if [[ "$ACTION" == "create" ]]; then
    info "Shared resource group $SHARED_RG_NAME not found; deploying it first..."
    run "$SCRIPT_DIR/deploy-shared.sh" create
  else
    error "Shared resource group $SHARED_RG_NAME not found; the shared ACR does not exist."
    error "Deploy it first (what-if never creates shared resources):"
    error "  ./scripts/deploy-shared.sh create"
    exit 1
  fi
elif [[ "$SHARED_RG_STATE" == "Deleting" ]]; then
  error "Shared resource group $SHARED_RG_NAME is still deleting (an ACR purge can take minutes)."
  error "Wait until it is gone, then retry. Check with:"
  error "  az group show --name \"$SHARED_RG_NAME\" --query properties.provisioningState -o tsv"
  exit 1
fi
step "Checking shared ACR $(registry_name) exists..."
if ! run_quiet az acr show -n "$(registry_name)"; then
  if [[ "$ACTION" == "create" ]]; then
    info "Shared ACR $(registry_name) not found in $SHARED_RG_NAME; redeploying it first..."
    run "$SCRIPT_DIR/deploy-shared.sh" create
  else
    error "Shared ACR $(registry_name) not found in $SHARED_RG_NAME."
    error "Redeploy it with:"
    error "  ./scripts/deploy-shared.sh create"
    exit 1
  fi
fi
success "Shared registry $(registry_name) found."

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

step "Checking if image exists in ACR..."
# The shared registry is guaranteed to exist by the check above; only the
# `api:<env>` tag can be missing (first deploy, or after a `--shared`
# teardown). Fall back to the helloworld image in that case — the real image is
# pushed by `az acr build` below (set -e does not trigger inside `if`).
if run_hide_stderr az acr repository show-tags -n "$(registry_name)" --repository api | grep -q "$ENVIRONMENT"; then
  success "  Image api:$ENVIRONMENT exists in ACR, using it for deployment."
  IMAGE="$(login_server)/api:$ENVIRONMENT"
else
  warn "  api:$ENVIRONMENT tag not found in $(registry_name), using default image for deployment."
  IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
fi
export IMAGE

step "Checking if key vault is soft-deleted"
if vault_is_soft_deleted; then
  error "Key Vault $VAULT_NAME is soft-deleted (name reserved, ~90 days)."
  error "Purge it (fresh vault, study-stack default):"
  error "  az keyvault purge --name \"$VAULT_NAME\" --location \"$LOCATION\""
  error "Or restore it with its old secrets:"
  error "  az keyvault recover --name \"$VAULT_NAME\" --location \"$LOCATION\""
  exit 1
else
  success "  Key Vault $VAULT_NAME is not soft-deleted."
fi

# Deploy the Bicep template to create the resource group and other resources
step "Starting $ACTION for $RG_NAME"
log_vars \
  "Action=$ACTION" \
  "Subscription=$(subscription_name) ($SUBSCRIPTION_ID)" \
  "Resource group=$RG_NAME" \
  "RG state=${RG_STATE:-absent}" \
  "Shared resource group=$SHARED_RG_NAME" \
  "KeyVault=$VAULT_NAME" \
  "CosmosAccount=$COSMOS_ACCOUNT_NAME" \
  "Location=$LOCATION" \
  "Deployment=$DEPLOYMENT_NAME" \
  "ImageTag=$IMAGE_TAG"

# run_deployment, not `run`: this call is silent for minutes at a time (ARM
# returns nothing until the deployment finishes), so it reports what it is
# waiting for instead of looking hung.
run_deployment "$RG_NAME" "$DEPLOYMENT_NAME" "$ACTION" \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$ROOT/infra/main.bicep" \
  --parameters "$ROOT/infra/main.bicepparam"

if [[ "$ACTION" == "what-if" ]]; then
  success "What-if analysis completed. No changes were made."
  exit 0
fi

if [[ "$BICEP_ONLY" == "1" ]]; then
  success "Bicep deployment completed. Stopping due to --bicep-only flag."
  success "Run the following manually to complete the deployment:"
  success "  1. Build and push Docker image: az acr build -r \$(registry_name) -t api:\$ENVIRONMENT -t api:\$IMAGE_TAG \$ROOT/api"
  success "  2. Update container app: az containerapp update --name <app-name> --resource-group $RG_NAME --image \$(login_server)/api:\$IMAGE_TAG"
  success "  3. Verify health: curl https://<fqdn>/health"
  exit 0
fi

# Keyless Cosmos (docs/phase-2/step-4.md): the account is deployed with
# disableLocalAuth, so account keys are dead and the API can only authenticate
# through the data-plane role assignment Bicep creates. An empty or partial
# assignment list still deploys cleanly — the failure only appears as a 403 the
# first time something reads the database, which is Phases 3-4 at the earliest.
# Check it here, while a broken grant still fails the deploy instead of being
# forgotten.
step "Checking Cosmos data-plane role assignments..."

# `az cosmosdb sql role assignment list` returns properties at the TOP level of
# each element (principalId, scope), not nested under a `properties` object —
# that is the raw ARM shape, not what the REST API docs suggest. Querying
# `[].properties.principalId` yields nulls and reads as "no assignments".
#
# `-o tsv` emits one scalar per line here, so `grep -qx` matches a whole id
# exactly. The tr() keeps it that way if a future az version switches to
# tab-separated output for flat arrays.
PRINCIPALS_RAW=""
attempt=1
max_attempts=6 # ~60s: the assignment can be listable a beat after the template succeeds
until PRINCIPALS_RAW=$(run_hide_stderr az cosmosdb sql role assignment list \
  --resource-group "$RG_NAME" \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --query '[].principalId' \
  -o tsv) && [[ -n "$PRINCIPALS_RAW" ]]; do
  if [[ "$attempt" -ge "$max_attempts" ]]; then
    error "No Cosmos data-plane role assignments on $COSMOS_ACCOUNT_NAME after ${max_attempts} attempts."
    error "Without them nothing can read the database (the account has local auth disabled)."
    error "Inspect them directly (the stderr log also has the hidden retry errors):"
    error "  az cosmosdb sql role assignment list -g \"$RG_NAME\" -a \"$COSMOS_ACCOUNT_NAME\" -o table"
    exit 1
  fi
  warn "Role assignments not visible yet (attempt $attempt/$max_attempts), retrying in 5s..."
  sleep 5
  attempt=$((attempt + 1))
done
PRINCIPAL_IDS="$(printf '%s' "$PRINCIPALS_RAW" | tr '\t' '\n')"
success "  Found $(printf '%s\n' "$PRINCIPAL_IDS" | grep -c . || true) role assignment(s)."

# The API identity must be among them: the list can be non-empty purely from the
# local-dev principal (COSMOS_USER_OBJECT_ID), which would pass the check above
# while the app itself is still unauthorised. Identity name mirrors identity.bicep.
if ! API_PRINCIPAL_ID=$(run_hide_stderr az identity show \
  --name "identity-${BASE_NAME}-${ENVIRONMENT}" \
  --resource-group "$RG_NAME" \
  --query principalId -o tsv) || [[ -z "$API_PRINCIPAL_ID" ]]; then
  error "Could not read the API managed identity principalId in $RG_NAME."
  error "  az identity show -n \"identity-${BASE_NAME}-${ENVIRONMENT}\" -g \"$RG_NAME\" --query principalId -o tsv"
  exit 1
fi
if ! grep -qxF "$API_PRINCIPAL_ID" <<< "$PRINCIPAL_IDS"; then
  error "API identity $API_PRINCIPAL_ID has no Cosmos data-plane role assignment."
  error "The app would deploy but fail every Cosmos call. Assignments found:"
  printf '%s\n' "$PRINCIPAL_IDS" >&2
  error "Expected the grant in infra/modules/cosmos.bicep (Built-in Data Contributor at database scope)."
  exit 1
fi
success "  API identity is granted data-plane access."

# The grants must also be the right ROLE, not merely present. cosmos.bicep
# grants by GUID, and the built-in data roles sit one character apart:
# ...0001 is Built-in Data Reader, ...0002 is Built-in Data Contributor.
# Nothing rejects the wrong one — ARM accepts it, the check above sees a
# principal on an assignment and passes, every read succeeds, and only writes
# fail Forbidden at runtime. A deploy that reports success here while granting
# Reader is exactly how that reaches the seed hours later.
#
# The granted ids are resolved to role names rather than compared against the
# Contributor GUID again, so this states the intent ("this grant can write")
# instead of repeating the constant it exists to police — change the role in
# cosmos.bicep and this follows it.
GRANTED_ROLE_ROWS="$(run_hide_stderr az cosmosdb sql role assignment list \
  --resource-group "$RG_NAME" \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --query '[].{p:principalId, r:roleDefinitionId}' \
  -o tsv)" || {
  error "Could not read Cosmos data-plane role assignments."
  exit 1
}

UNWRITABLE=""
while IFS=$'\t' read -r granted_principal granted_role_id; do
  [[ -z "$granted_role_id" ]] && continue
  # roleDefinitionId is the full ARM resource path; the definition list keys on
  # the bare GUID.
  granted_role_name="$(run_hide_stderr az cosmosdb sql role definition list \
    --resource-group "$RG_NAME" \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --query "[?name=='${granted_role_id##*/}'].roleName" \
    -o tsv)" || granted_role_name=""
  if [[ "$granted_role_name" != "Cosmos DB Built-in Data Contributor" ]]; then
    UNWRITABLE+="${granted_principal} (${granted_role_name:-unknown role ${granted_role_id##*/}})"$'\n'
  fi
done <<< "$GRANTED_ROLE_ROWS"

if [[ -n "$UNWRITABLE" ]]; then
  error "Cosmos data-plane grants that cannot write:"
  printf '%s' "$UNWRITABLE" | while IFS= read -r line; do error "  $line"; done
  error "Data Reader grants pass a presence check but fail every upsert with Forbidden."
  error "Fix the role id in infra/modules/cosmos.bicep (...0002 = Data Contributor) and redeploy."
  exit 1
fi
success "  All data-plane grants are Built-in Data Contributor."

# One round trip for all four outputs (array order is preserved in -o tsv).
# Outputs can lag the Succeeded state (ARM eventual consistency), so poll.
DEPLOYMENT_OUTPUTS="$(fetch_deployment_outputs "$DEPLOYMENT_NAME" \
  "[properties.outputs.registryName.value, properties.outputs.loginServer.value, properties.outputs.appName.value, properties.outputs.fqdn.value]" 4)" || exit 1
IFS=$'\t' read -r REGISTRY LOGIN_SERVER APP_NAME FQDN <<< "$DEPLOYMENT_OUTPUTS" || true

log_vars \
  "REGISTRY=$REGISTRY" \
  "LOGIN_SERVER=$LOGIN_SERVER" \
  "APP_NAME=$APP_NAME" \
  "FQDN=$FQDN"

if [[ "$(login_server)" != "$LOGIN_SERVER" ]]; then
  error "Login server mismatch"
  exit 1
fi

step "Building and pushing Docker image to ACR..."
# Push both the floating env tag (keeps the Bicep pre-check working and marks
# latest-stable) and the unique timestamp tag (guarantees a template-string
# change so `containerapp update` mints a new revision every run).
run az acr build -r "$REGISTRY" -t api:"$ENVIRONMENT" -t api:"$IMAGE_TAG" "$ROOT/api"

step "Deploying container app..."
run az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RG_NAME" \
  --image "$LOGIN_SERVER/api:$IMAGE_TAG"

step "Waiting for https://${FQDN}/health ..."
attempt=1
max_attempts=12 # ~60s: covers ACR pull + scale-from-zero on Consumption
until run curl -sSf --max-time 5 "https://${FQDN}/health" | jq; do
  if [[ "$attempt" -ge "$max_attempts" ]]; then
    error "Health check failed after $max_attempts attempts."
    exit 1
  fi
  warn "Attempt $attempt/$max_attempts failed, retrying in 5s..."
  sleep 5
  attempt=$((attempt + 1))
done
success "API is healthy at https://${FQDN}/health."
