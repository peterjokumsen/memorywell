#!/usr/bin/env bash
# Phase 1 — prepare outline (human fills TODOs; see docs/phase-1-brief.md §4).
# NOTE: brief/PLAN name this deploy.sh; this file is prepare.sh — rename or
# update the brief before Phase 1 gate if keeping this name.
set -euo pipefail

# TODO: source local .env (never commit it) and set:
#   SUBSCRIPTION_ID, RG_NAME, LOCATION, BASE_NAME
: "${RG_NAME:=TODO-rg-name}"
: "${LOCATION:=TODO-location}"

echo "TODO: az account show (verify subscription)"
echo "TODO: az group create --name $RG_NAME --location $LOCATION"
echo "TODO: az deployment group create --resource-group $RG_NAME --template-file infra/main.bicep"
echo "TODO: az acr build -r TODO-registry -t api:phase1 ./api"
echo "TODO: az containerapp update --name TODO-api-app --resource-group $RG_NAME --image TODO-registry/api:phase1"

echo "prepare.sh outline only — fill TODOs, then implement."
