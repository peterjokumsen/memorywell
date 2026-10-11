#!/usr/bin/env bash
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Validate args before touching Azure.
ACTION="${1:-create}"
if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  error "$1 is not a valid action"
  echo "Usage: $0 [create|what-if]"
  exit 1
fi

registry_name() { echo "acr${BASE_NAME}${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]' | tr -d '-'; }
login_server() { echo "$(registry_name).azurecr.io"; }

# Set the subscription context for Azure CLI commands
az account set --subscription $SUBSCRIPTION_ID

# Guard against redeploying while a previous teardown is still draining.
# `teardown.sh` deletes the RG with --no-wait and the managed environment
# takes a while to delete, so the RG lingers in Deleting state; a Bicep
# sub-deployment issued in that window fails. Fail fast instead.
step "Checking resource group $RG_NAME state..."
if RG_STATE=$(az group show --name "$RG_NAME" --query properties.provisioningState -o tsv 2>/dev/null); then
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
# Tolerate missing registry/repo on first deploy: `az acr show` and
# `show-tags` return non-zero when the RG/ACR does not exist yet or the
# repo/tag was never pushed. Both are expected pre-first-deploy, so fall
# back to the helloworld image instead of failing (set -e does not trigger
# inside `if`, but the nesting below makes the intent explicit).
if az acr show -n "$(registry_name)" 2>/dev/null 1>&2; then
  if az acr repository show-tags -n "$(registry_name)" --repository api 2>/dev/null | grep -q "$ENVIRONMENT"; then
    success "Image api:$ENVIRONMENT exists in ACR, using it for deployment."
    export IMAGE="$(login_server)/api:$ENVIRONMENT"
  else
    warn "ACR exists but api:$ENVIRONMENT tag not found, using default image for deployment."
    export IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
  fi
else
  warn "ACR $(registry_name) not found (expected on first deploy), using default image for deployment."
  export IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
fi

# Deploy the Bicep template to create the resource group and other resources
log_vars \
  "Action=$ACTION" \
  "Subscription=$SUBSCRIPTION_ID" \
  "Resource group=$RG_NAME" \
  "RG state=${RG_STATE:-absent}" \
  "Location=$LOCATION" \
  "Deployment=$DEPLOYMENT_NAME" \
  "ImageTag=$IMAGE_TAG"

az deployment sub "$ACTION" \
  --location $LOCATION \
  --name $DEPLOYMENT_NAME \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

if [[ "$ACTION" == "what-if" ]]; then
  success "What-if analysis completed. No changes were made."
  exit 0
fi

REGISTRY=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.registryName.value -o tsv)
LOGIN_SERVER=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.loginServer.value -o tsv)
APP_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.appName.value -o tsv)
FQDN=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.fqdn.value -o tsv)

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
az acr build -r "$REGISTRY" -t api:$ENVIRONMENT -t api:$IMAGE_TAG ./api

step "Deploying container app..."
az containerapp update \
  --name "$APP_NAME" \
  --resource-group $RG_NAME \
  --image "$LOGIN_SERVER/api:$IMAGE_TAG"

step "Waiting for https://${FQDN}/health ..."
attempt=1
max_attempts=12 # ~60s: covers ACR pull + scale-from-zero on Consumption
until curl -sSf --max-time 5 "https://${FQDN}/health" | jq; do
  if [[ "$attempt" -ge "$max_attempts" ]]; then
    error "Health check failed after $max_attempts attempts."
    exit 1
  fi
  warn "Attempt $attempt/$max_attempts failed, retrying in 5s..."
  sleep 5
  attempt=$((attempt + 1))
done
success "API is healthy at https://${FQDN}/health."
