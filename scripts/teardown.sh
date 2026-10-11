#!/usr/bin/env bash
# Phase 1 — teardown outline (human fills TODOs; see docs/phase-1-brief.md §4).
# Destroys everything between study sessions. Cost control depends on this.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log_vars \
  "Subscription=$SUBSCRIPTION_ID" \
  "Resource group=$RG_NAME"

az account set --subscription $SUBSCRIPTION_ID

echo "Groups in subscription $SUBSCRIPTION_ID:"
az group list --query '[].name' -o tsv

echo "Deleting resource group $RG_NAME..."
az group delete --name $RG_NAME --yes --no-wait
