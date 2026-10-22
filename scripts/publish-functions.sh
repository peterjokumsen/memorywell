#!/usr/bin/env bash
# Publish the Python Function App code with Azure Functions Core Tools.
#
# The Function App itself (consumption plan, Python 3.11) is deployed by
# infra/modules/functions.bicep through provision-env.sh; this script only ships
# the code in functions/ (zip deploy + remote build) and points Bruno at the
# resulting hostname. Run it after a successful Bicep deployment.
#
# Why Core Tools and not `az`: `func azure functionapp publish` performs the
# Linux consumption remote build (Oryx restores requirements.txt) and uploads
# only the project, so there is no container image and no local Python
# packaging step to keep in sync.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=_bruno.sh
source "${_SCRIPTS_DIR}/_bruno.sh"

init_command_log "publish-functions"

if ! command -v func >/dev/null 2>&1; then
  error "Azure Functions Core Tools (func) not found."
  error "Install it with: npm install -g azure-functions-core-tools@4 --unsafe-perm"
  exit 1
fi

# Set the subscription context: `func azure functionapp publish` resolves the
# app through the az CLI's current subscription.
run az account set --subscription "$SUBSCRIPTION_ID"

step "Checking resource group $RG_NAME..."
if ! RG_STATE=$(run_hide_stderr az group show --name "$RG_NAME" --query properties.provisioningState -o tsv); then
  error "Resource group $RG_NAME does not exist. Run provision-env.sh first."
  exit 1
fi
if [[ "$RG_STATE" == "Deleting" ]]; then
  error "Resource group $RG_NAME is still deleting."
  exit 1
fi

step "Checking Function App $FUNCTION_APP_NAME..."
if ! APP_STATE=$(run_hide_stderr az functionapp show \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RG_NAME" \
  --query state -o tsv) || [[ -z "$APP_STATE" ]]; then
  error "Function App $FUNCTION_APP_NAME not found in $RG_NAME."
  error "Deploy the infrastructure first: ./scripts/provision-env.sh --bicep-only"
  exit 1
fi
success "  Function App state: $APP_STATE"

if [[ ! -f "$ROOT/functions/function_app.py" ]]; then
  error "Missing $ROOT/functions/function_app.py (Python v2 entry point)."
  exit 1
fi

step "Publishing $ROOT/functions to $FUNCTION_APP_NAME..."
# Core Tools detects the Python worker from host.json/function_app.py and, for a
# Linux consumption app, builds requirements.txt remotely. Run from functions/
# so only the project is zipped (the local .venv and local.settings.json are
# excluded by .funcignore).
(
  cd "$ROOT/functions"
  run func azure functionapp publish "$FUNCTION_APP_NAME"
)

step "Reading the deployed hostname..."
if ! APP_HOSTNAME=$(run_hide_stderr az functionapp show \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RG_NAME" \
  --query defaultHostName -o tsv) || [[ -z "$APP_HOSTNAME" ]]; then
  warn "Could not read defaultHostName for $FUNCTION_APP_NAME."
else
  log_vars \
    "FunctionApp=$FUNCTION_APP_NAME" \
    "Hostname=$APP_HOSTNAME" \
    "LogUrl=https://${APP_HOSTNAME}/api/log"

  BRUNO_DEV_ENV="$ROOT/bruno/environments/dev.yml"
  if [[ -f "$BRUNO_DEV_ENV" ]]; then
    if bruno_set_var "$BRUNO_DEV_ENV" "fns_url" "https://${APP_HOSTNAME}"; then
      success "  Bruno fns_url -> https://${APP_HOSTNAME}"
    else
      warn "  Bruno variable 'fns_url' not found in ${BRUNO_DEV_ENV#"$ROOT"/}"
    fi
  else
    warn "  Bruno dev environment not found at ${BRUNO_DEV_ENV#"$ROOT"/}"
  fi
fi

success "Function App code published: $FUNCTION_APP_NAME"
