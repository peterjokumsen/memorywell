#!/usr/bin/env bash
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

registry_name() { echo "acr${BASE_NAME}${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]' | tr -d '-'; }
login_server() { echo "$(registry_name).azurecr.io"; }

# Set the subscription context for Azure CLI commands
az account set --subscription $SUBSCRIPTION_ID

echo "Checking if image exists in ACR..."
# Tolerate missing registry/repo on first deploy: `az acr show` and
# `show-tags` return non-zero when the RG/ACR does not exist yet or the
# repo/tag was never pushed. Both are expected pre-first-deploy, so fall
# back to the helloworld image instead of failing (set -e does not trigger
# inside `if`, but the nesting below makes the intent explicit).
if az acr show -n "$(registry_name)" 2>/dev/null 1>&2; then
  if az acr repository show-tags -n "$(registry_name)" --repository api 2>/dev/null | grep -q "$ENVIRONMENT"; then
    echo "Image api:$ENVIRONMENT exists in ACR, using it for deployment."
    export IMAGE="$(login_server)/api:$ENVIRONMENT"
  else
    echo "ACR exists but api:$ENVIRONMENT tag not found, using default image for deployment."
    export IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
  fi
else
  echo "ACR $(registry_name) not found (expected on first deploy), using default image for deployment."
  export IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
fi

# Deploy the Bicep template to create the resource group and other resources
ACTION="${1:-create}"
if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  echo "$1 is not a valid action"
  echo "Usage: $0 [create|what-if]"
  exit 1
fi

log_vars \
  "Action=$ACTION" \
  "Subscription=$SUBSCRIPTION_ID" \
  "Resource group=$RG_NAME" \
  "Location=$LOCATION" \
  "Deployment=$DEPLOYMENT_NAME"

az deployment sub "$ACTION" \
  --location $LOCATION \
  --name $DEPLOYMENT_NAME \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

if [[ "$ACTION" == "what-if" ]]; then
  echo "What-if analysis completed. No changes were made."
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
  echo "ERROR: login server mismatch"
  exit 1
fi

echo "Building and pushing Docker image to ACR..."
az acr build -r "$REGISTRY" -t api:$ENVIRONMENT ./api

echo "Deploying container app..."
az containerapp update \
  --name "$APP_NAME" \
  --resource-group $RG_NAME \
  --image "$LOGIN_SERVER/api:$ENVIRONMENT"

echo "Waiting for https://${FQDN}/health ..."
attempt=1
max_attempts=12 # ~60s: covers ACR pull + scale-from-zero on Consumption
until curl -sSf --max-time 5 "https://${FQDN}/health" | jq; do
  if [[ "$attempt" -ge "$max_attempts" ]]; then
    echo "Health check failed after $max_attempts attempts."
    exit 1
  fi
  echo "Attempt $attempt/$max_attempts failed, retrying in 5s..."
  sleep 5
  attempt=$((attempt + 1))
done
