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

init_command_log "deploy-shared"

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

run az account set --subscription "$SUBSCRIPTION_ID"

step "Checking shared resource group $SHARED_RG_NAME state..."
if SHARED_RG_STATE=$(run az group show --name "$SHARED_RG_NAME" --query properties.provisioningState -o tsv 2>/dev/null); then
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

run az deployment sub "$ACTION" \
  --location "$LOCATION" \
  --name "$SHARED_DEPLOYMENT_NAME" \
  --template-file infra/shared.bicep \
  --parameters infra/shared.bicepparam

if [[ "$ACTION" == "what-if" ]]; then
  success "What-if analysis completed. No changes were made."
  exit 0
fi

# The subscription deployment call above blocks, but the shared RG/ACR can
# lag behind (eventual consistency) or report a non-terminal state on a
# slow run. Poll the deployment provisioningState until it reads Succeeded.
step "Waiting for shared deployment $SHARED_DEPLOYMENT_NAME to succeed..."
attempt=1
max_attempts=15 # 15 x 60s: ACR + RG propagation can take minutes
while true; do
  SHARED_STATE=$(run az deployment sub show --name "$SHARED_DEPLOYMENT_NAME" \
    --query properties.provisioningState -o tsv 2>/dev/null || true)
  if [[ "$SHARED_STATE" == "Succeeded" ]]; then
    success "Shared deployment $SHARED_DEPLOYMENT_NAME succeeded."
    break
  fi
  if [[ "$SHARED_STATE" == "Failed" || "$SHARED_STATE" == "Canceled" ]]; then
    error "Shared deployment $SHARED_DEPLOYMENT_NAME ended with state: $SHARED_STATE."
    run az deployment sub show --name "$SHARED_DEPLOYMENT_NAME" \
      --query properties.error -o json 2>/dev/null || true
    exit 1
  fi
  if [[ "$attempt" -ge "$max_attempts" ]]; then
    error "Shared deployment $SHARED_DEPLOYMENT_NAME not Succeeded after $max_attempts checks (last state: ${SHARED_STATE:-unknown})."
    exit 1
  fi
  warn "Attempt $attempt/$max_attempts: state is ${SHARED_STATE:-unknown}, retrying in 60s..."
  sleep 60
  attempt=$((attempt + 1))
done

SHARED_REGISTRY=$(run az deployment sub show --name "$SHARED_DEPLOYMENT_NAME" \
  --query properties.outputs.registryName.value -o tsv)
SHARED_LOGIN_SERVER=$(run az deployment sub show --name "$SHARED_DEPLOYMENT_NAME" \
  --query properties.outputs.loginServer.value -o tsv)

log_vars \
  "REGISTRY=$SHARED_REGISTRY" \
  "LOGIN_SERVER=$SHARED_LOGIN_SERVER"

if [[ "$(login_server)" != "$SHARED_LOGIN_SERVER" ]]; then
  error "Login server mismatch (expected $(login_server))"
  exit 1
fi
success "Shared resources deployed; registry $SHARED_REGISTRY is ready."
