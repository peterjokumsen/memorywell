#!/usr/bin/env bash
# Phase 1 — teardown. Destroys everything between study sessions.
# Cost control depends on this. See docs/phase-1/step-6.md.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Usage: teardown.sh [--purge-vault] [--shared]
#   --purge-vault  after deleting the RG, wait for the soft-deleted Key Vault
#                  to appear and purge it so same-name redeploys do not conflict.
#                  Without the flag, only the RG delete runs (fast, async).
#   --shared       also delete the shared resource group (ACR). Not the default:
#                  the shared RG survives study-session teardowns, and deleting
#                  it first would break image pulls from any running app.
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [--purge-vault] [--shared]"
  exit 0
fi
PURGE_VAULT=0
DELETE_SHARED=0
for arg in "$@"; do
  case "$arg" in
    --purge-vault) PURGE_VAULT=1 ;;
    --shared) DELETE_SHARED=1 ;;
    *)
      error "Unknown argument: $arg"
      echo "Usage: $0 [--purge-vault] [--shared]"
      exit 1
      ;;
  esac
done

VAULT_NAME="kv-${BASE_NAME}-${ENVIRONMENT}"

log_vars \
  "Subscription=$SUBSCRIPTION_ID" \
  "Resource group=$RG_NAME" \
  "KeyVault=$VAULT_NAME" \
  "PurgeVault=$PURGE_VAULT" \
  "DeleteShared=$DELETE_SHARED"

az account set --subscription $SUBSCRIPTION_ID

step "Groups in subscription $SUBSCRIPTION_ID:"
az group list --query '[].name' -o tsv

step "Deleting resource group $RG_NAME..."
if [[ "$(az group exists --name "$RG_NAME" -o tsv)" == "true" ]]; then
  az group delete --name "$RG_NAME" --yes --no-wait
else
  info "Resource group $RG_NAME not found; skipping delete."
fi

# Key Vault uses soft-delete: after the RG is gone the vault lingers in
# "deleted" state and blocks same-name redeploy. Purge is opt-in via
# --purge-vault because the RG delete is async (--no-wait) and the vault may
# take minutes to reach soft-deleted state.
if [[ "$PURGE_VAULT" == "1" ]]; then
  step "Waiting for soft-deleted Key Vault $VAULT_NAME (up to ~5 min)..."
  attempt=1
  max_attempts=30
  while ! az keyvault list-deleted --query "[?name=='$VAULT_NAME'].name" -o tsv 2>/dev/null | grep -q "$VAULT_NAME"; do
    if [[ "$attempt" -ge "$max_attempts" ]]; then
      error "Vault $VAULT_NAME not soft-deleted yet; purge skipped. Retry later:"
      error "  az keyvault list-deleted --query \"[?name=='$VAULT_NAME']\" -o table"
      error "  az keyvault purge --name \"$VAULT_NAME\""
      exit 1
    fi
    warn "Attempt $attempt/$max_attempts: not soft-deleted yet, retrying in 10s..."
    sleep 10
    attempt=$((attempt + 1))
  done
  step "Purging soft-deleted Key Vault $VAULT_NAME..."
  az keyvault purge --name "$VAULT_NAME"
  info "Environment resource group deleted, vault purged."
else
  info "Skipping Key Vault purge (pass --purge-vault to purge $VAULT_NAME for same-name redeploy)."
fi

# Shared RG last (only with --shared): the env RG is deleted first so no
# running container app can lose its image pull mid-teardown.
if [[ "$DELETE_SHARED" == "1" ]]; then
  step "Deleting shared resource group $SHARED_RG_NAME..."
  if [[ "$(az group exists --name "$SHARED_RG_NAME" -o tsv)" == "true" ]]; then
    az group delete --name "$SHARED_RG_NAME" --yes --no-wait
  else
    info "Shared resource group $SHARED_RG_NAME not found; skipping delete."
  fi
  success "Teardown complete (environment and shared resource groups deleting)."
else
  info "Shared resource group $SHARED_RG_NAME kept (pass --shared to delete it too)."
fi
