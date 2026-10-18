#!/usr/bin/env bash
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Validate args before touching Azure.
ACTION="${1:-create}"
if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  error "${1-} is not a valid action"
  echo "Usage: $0 [create|what-if]" >&2
  exit 1
fi

init_command_log "deploy"

# Mint the timestamped deployment name + image tag (lazy: sourcing common.sh
# alone reserves nothing; see deployment_name in common.sh).
DEPLOYMENT_NAME="$(deployment_name)"
IMAGE_TAG="$(image_tag)"
export DEPLOYMENT_NAME IMAGE_TAG

# Set the subscription context for Azure CLI commands
run az account set --subscription "$SUBSCRIPTION_ID"

# The ACR lives in the shared resource group and must exist before the env
# deployment: main.bicep declares it as `existing`, so a missing registry fails
# the Bicep deployment partway through (after the env RG is created). On
# `create`, deploy it automatically so one script call provisions everything;
# `what-if` never creates anything, so it still fails fast with the fix.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
step "Checking shared resource group $SHARED_RG_NAME (ACR)..."
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
  "Location=$LOCATION" \
  "Deployment=$DEPLOYMENT_NAME" \
  "ImageTag=$IMAGE_TAG"

# run_deployment, not `run`: this call is silent for minutes at a time (ARM
# returns nothing until the deployment finishes), so it reports what it is
# waiting for instead of looking hung.
run_deployment "$DEPLOYMENT_NAME" "$ACTION" \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$ROOT/infra/main.bicep" \
  --parameters "$ROOT/infra/main.bicepparam"

if [[ "$ACTION" == "what-if" ]]; then
  success "What-if analysis completed. No changes were made."
  exit 0
fi

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
