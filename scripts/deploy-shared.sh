#!/usr/bin/env bash
# One-time (per subscription) shared-resource deployment: the resource group
# holding resources every environment shares, starting with the ACR.
# Run before the first `deploy.sh`; `deploy.sh` fails fast if this is missing.
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

# Subscription-deployment names must be unique per `az deployment sub create`
# run (same reason as the env deployment in common.sh): re-using a name
# overwrites history. Shared deployments get their own file so a shared run
# never clobbers the env one (and vice versa).
SHARED_DEPLOYMENT_FILE="${TMPDIR:-/tmp}/memorywell-${BASE_NAME}-shared.deployment"
if [[ -n "${REUSE_DEPLOYMENT:-}" && -f "$SHARED_DEPLOYMENT_FILE" ]]; then
  SHARED_DEPLOYMENT_NAME="$(cat "$SHARED_DEPLOYMENT_FILE")"
else
  SHARED_DEPLOYMENT_NAME="${BASE_NAME}-shared-$(date -u +%Y%m%d-%H%M%S)"
  printf '%s' "$SHARED_DEPLOYMENT_NAME" > "$SHARED_DEPLOYMENT_FILE"
fi

az account set --subscription "$SUBSCRIPTION_ID"

step "Checking shared resource group $SHARED_RG_NAME state..."
if SHARED_RG_STATE=$(az group show --name "$SHARED_RG_NAME" --query properties.provisioningState -o tsv 2>/dev/null); then
  success "Resource group $SHARED_RG_NAME exists (provisioningState: $SHARED_RG_STATE)."
  if [[ "$SHARED_RG_STATE" == "Deleting" ]]; then
    error "Resource group $SHARED_RG_NAME is still deleting (an ACR purge can take minutes)."
    error "Wait until it is gone, then retry. Check with:"
    error "  az group show --name \"$SHARED_RG_NAME\" --query properties.provisioningState -o tsv"
    exit 1
  fi
else
  info "Resource group $SHARED_RG_NAME does not exist (expected on first run)."
  SHARED_RG_STATE="absent"
fi

log_vars \
  "Action=$ACTION" \
  "Subscription=$SUBSCRIPTION_ID" \
  "Shared resource group=$SHARED_RG_NAME" \
  "RG state=$SHARED_RG_STATE" \
  "Registry=$SHARED_ACR_NAME" \
  "Location=$LOCATION" \
  "Deployment=$SHARED_DEPLOYMENT_NAME"

az deployment sub "$ACTION" \
  --location "$LOCATION" \
  --name "$SHARED_DEPLOYMENT_NAME" \
  --template-file infra/shared.bicep \
  --parameters infra/shared.bicepparam

if [[ "$ACTION" == "what-if" ]]; then
  success "What-if analysis completed. No changes were made."
  exit 0
fi

SHARED_REGISTRY=$(az deployment sub show --name "$SHARED_DEPLOYMENT_NAME" \
  --query properties.outputs.registryName.value -o tsv)
SHARED_LOGIN_SERVER=$(az deployment sub show --name "$SHARED_DEPLOYMENT_NAME" \
  --query properties.outputs.loginServer.value -o tsv)

log_vars \
  "REGISTRY=$SHARED_REGISTRY" \
  "LOGIN_SERVER=$SHARED_LOGIN_SERVER"

if [[ "$(login_server)" != "$SHARED_LOGIN_SERVER" ]]; then
  error "Login server mismatch (expected $(login_server))"
  exit 1
fi
success "Shared resources deployed; registry $SHARED_REGISTRY is ready."
