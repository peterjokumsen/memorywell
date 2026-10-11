#!/usr/bin/env bash
# Phase 1 — teardown. Destroys everything between study sessions.
# Cost control depends on this. See docs/phase-1-brief.md §4 step 6.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

VAULT_NAME="kv-${BASE_NAME}-${ENVIRONMENT}"

log_vars \
  "Subscription=$SUBSCRIPTION_ID" \
  "Resource group=$RG_NAME" \
  "KeyVault=$VAULT_NAME"

az account set --subscription $SUBSCRIPTION_ID

echo "Groups in subscription $SUBSCRIPTION_ID:"
az group list --query '[].name' -o tsv

echo "Deleting resource group $RG_NAME..."
az group delete --name $RG_NAME --yes --no-wait

# Key Vault uses soft-delete: after the RG is gone the vault lingers in
# "deleted" state and blocks same-name redeploy. The delete above is
# async (--no-wait), so the purge below may run before the vault is
# soft-deleted — failure is expected then and is safe to ignore. If a later
# redeploy fails with a vault-name conflict, run:
#   az keyvault list-deleted --query "[?name=='$VAULT_NAME']" -o table
#   az keyvault purge --name "$VAULT_NAME"
echo "Purging soft-deleted Key Vault $VAULT_NAME (if present)..."
az keyvault purge --name "$VAULT_NAME" 2>/dev/null \
  || echo "Purge skipped: vault not in deleted state yet (see hint above if redeploy conflicts)."
