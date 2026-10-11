#!/usr/bin/env bash
# Phase 1 — teardown outline (human fills TODOs; see docs/phase-1-brief.md §4).
# Destroys everything between study sessions. Cost control depends on this.
set -euo pipefail

# TODO: source local .env (never commit it) and set RG_NAME.
: "${RG_NAME:=TODO-rg-name}"

echo "TODO: az group delete --name $RG_NAME --yes --no-wait"
echo "TODO: echo what was removed + verify with 'az group show'"

echo "teardown.sh outline only — fill TODOs, then implement."
