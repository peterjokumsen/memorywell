#!/usr/bin/env bash
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

registry_name() { echo "acr${BASE_NAME}${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]' | tr -d '-'; }
login_server() { echo "$(registry_name).azurecr.io"; }

# Set the subscription context for Azure CLI commands
az account set --subscription $SUBSCRIPTION_ID

if az acr repository show-tags -n "$REGISTRY" --repository api 2>/null | grep -q "$ENVIRONMENT"; then
  IMAGE="$(login_server)/api:$ENVIRONMENT"
else
  IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
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

REGISTRY=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.registryName.value -o tsv)
LOGIN_SERVER=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query properties.outputs.loginServer.value -o tsv)

log_vars \
  "REGISTRY=$REGISTRY" \
  "LOGIN_SERVER=$LOGIN_SERVER"

if [[ "$(login_server)" != "$LOGIN_SERVER" ]]; then
  echo "ERROR: login server mismatch"
  exit 1
fi

echo "TODO: az acr build -r TODO-registry -t api:$ENVIRONMENT ./api"
echo "TODO: az containerapp update --name TODO-api-app --resource-group $RG_NAME --image TODO-registry/api:$ENVIRONMENT"

echo "deploy.sh outline only — fill TODOs, then implement."
