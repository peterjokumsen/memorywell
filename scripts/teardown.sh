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
#                  VAULT_PURGE_WAIT_MINUTES (default 10) caps that wait.
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
      echo "Usage: $0 [--purge-vault] [--shared]" >&2
      exit 1
      ;;
  esac
done

init_command_log "teardown"

log_vars \
  "Subscription=$SUBSCRIPTION_ID" \
  "Resource group=$RG_NAME" \
  "KeyVault=$VAULT_NAME" \
  "PurgeVault=$PURGE_VAULT" \
  "DeleteShared=$DELETE_SHARED"

run az account set --subscription "$SUBSCRIPTION_ID"

step "Groups in subscription $SUBSCRIPTION_ID:"
run az group list --query '[].name' -o tsv

step "Deleting resource group $RG_NAME..."
# No early exit when the group is absent: the vault purge and the optional
# shared-RG delete below must still run (e.g. scheduled run after a previous
# teardown already removed the group).
ENV_RG_EXISTS="$(group_exists "$RG_NAME")" || exit 1
if [[ "$ENV_RG_EXISTS" == "true" ]]; then
  run az group delete --name "$RG_NAME" --yes --no-wait
else
  info "Resource group $RG_NAME not found; skipping delete."
fi

# Was $VAULT_NAME live before the delete above? After it there is no way to tell
# "the vault is still coming" from "there was no vault": a vault that was purged
# in an earlier run (or one the group never had) never appears in `list-deleted`,
# so wait_for_soft_deleted_vault below would burn its whole budget and then fail
# the teardown for a vault that does not exist. One probe, taken while the vault
# still answers, settles which of the two this is — and it is only needed when a
# purge was asked for, so runs without --purge-vault pay nothing for it.
VAULT_WAS_LIVE=0
if [[ "$PURGE_VAULT" == "1" ]]; then
  # No `2>/dev/null` here: a redirect on run/itself swallows the `+ az …`
  # trace it prints to stderr. run_hide_stderr already keeps the probe's own
  # stderr (which is expected to fail, and belongs in the log) off the console;
  # only its stdout — a JSON blob — is discarded.
  if run_hide_stderr az keyvault show --name "$VAULT_NAME" >/dev/null; then
    VAULT_WAS_LIVE=1
    info "Key Vault $VAULT_NAME is live now; waiting for it to reach soft-deleted after the delete."
  else
    info "Key Vault $VAULT_NAME was not live before the delete (already purged, or never existed)."
  fi
fi

# Key Vault uses soft-delete: after the RG is gone the vault lingers in
# "deleted" state and blocks same-name redeploy. Purge is opt-in via
# --purge-vault because the RG delete is async (--no-wait) and the vault may
# take minutes to reach soft-deleted state.
#
# The race this has to survive: right after `az group delete --no-wait`, the
# vault is in a transient state where `az keyvault show` fails (the resource is
# being deleted) but `list-deleted` does not list it yet. Concluding "no vault,
# nothing to purge" there is wrong — minutes later the vault does surface as
# soft-deleted, which is exactly what the workflow's Verify step then trips
# over. So: when this run deleted a group that held a live vault, wait for the
# vault to surface instead of deciding early. When the group was absent, or held
# no live vault, a missing vault does mean "already purged in an earlier run" —
# and VAULT_WAS_LIVE above is what keeps those two cases apart.
wait_for_soft_deleted_vault() {
  local attempt=1
  local wait_minutes="${VAULT_PURGE_WAIT_MINUTES:-10}"
  local max_attempts=$((wait_minutes * 60 / 10))
  step "Waiting for soft-deleted Key Vault $VAULT_NAME (up to ~${wait_minutes} min)..."
  # Grouped so the probes collapse into one section in the nightly GitHub
  # Actions log. Group the block only at top level, never around a $(...)
  # capture, and always close it — an unclosed group swallows the rest of the
  # step's output.
  group "Waiting for $VAULT_NAME to become soft-deleted"
  while ! vault_is_soft_deleted; do
    if [[ "$attempt" -ge "$max_attempts" ]]; then
      endgroup
      error "Vault $VAULT_NAME did not become soft-deleted within ${wait_minutes} min; purge skipped. Retry later:"
      error "  az keyvault purge --name \"$VAULT_NAME\""
      return 1
    fi
    warn "Attempt $attempt/$max_attempts: not soft-deleted yet, retrying in 10s..."
    sleep 10
    attempt=$((attempt + 1))
  done
  endgroup
}

if [[ "$PURGE_VAULT" == "1" ]]; then
  # Wait only when this run deleted a group that held a live vault. Any other
  # route falls through to the soft-delete probe, which is the correct answer
  # for both "no group to delete" and "the vault was never there".
  if [[ "$ENV_RG_EXISTS" == "true" && "$VAULT_WAS_LIVE" == "1" ]]; then
    # This run deleted the group, so the vault's fate is still being decided.
    if wait_for_soft_deleted_vault; then
      step "Purging soft-deleted Key Vault $VAULT_NAME..."
      run az keyvault purge --name "$VAULT_NAME"
      # `success`, not `info`: this is the outcome the run exists to produce, and
      # the GitHub backend puts successes in the workflow summary (see
      # _log-ghactions.sh) while `info` stays log-only.
      success "Environment resource group deleted, vault purged."
    else
      exit 1
    fi
  elif vault_is_soft_deleted; then
    # Nothing to delete, but a previous run left the vault soft-deleted.
    step "Purging soft-deleted Key Vault $VAULT_NAME..."
    run az keyvault purge --name "$VAULT_NAME"
    success "Key Vault $VAULT_NAME purged."
  else
    success "Key Vault $VAULT_NAME is neither live nor soft-deleted; nothing to purge (already purged in an earlier run, or never existed)."
  fi
else
  info "Skipping Key Vault purge (pass --purge-vault to purge $VAULT_NAME for same-name redeploy)."
fi

# Shared RG last (only with --shared): the env RG is deleted first so no
# running container app can lose its image pull mid-teardown.
if [[ "$DELETE_SHARED" == "1" ]]; then
  step "Deleting shared resource group $SHARED_RG_NAME..."
  SHARED_RG_EXISTS="$(group_exists "$SHARED_RG_NAME")" || exit 1
  if [[ "$SHARED_RG_EXISTS" == "true" ]]; then
    run az group delete --name "$SHARED_RG_NAME" --yes --no-wait
  else
    info "Shared resource group $SHARED_RG_NAME not found; skipping delete."
  fi
  success "Teardown complete (environment and shared resource groups deleting)."
else
  info "Shared resource group $SHARED_RG_NAME kept (pass --shared to delete it too)."
fi
