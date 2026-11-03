#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ACTION="create"
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action) ACTION="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--action create|what-if] [--only foundation|databases|functions|containerapp|eventgrid]"; exit 0 ;;
    *) error "Unknown arg $1"; exit 1 ;;
  esac
done
init_command_log "provision-env"

COMPLETED_STEPS=()
CURRENT_STEP=""
on_error() {
  local rc=$?
  error "Provisioning failed (exit $rc)."
  if [[ -n "$CURRENT_STEP" ]]; then
    error "Failed step: $CURRENT_STEP"
  fi
  if (( ${#COMPLETED_STEPS[@]} > 0 )); then
    success "Steps completed successfully before failure:"
    for s in "${COMPLETED_STEPS[@]}"; do
      success "  - $s"
    done
  else
    warn "No steps completed successfully before failure."
  fi
  exit "$rc"
}
trap on_error ERR

run az account set --subscription "$SUBSCRIPTION_ID"

CURRENT_STEP="provision-foundation"
step "provision-foundation"
run "$SCRIPT_DIR/provision-foundation.sh" "$ACTION"
COMPLETED_STEPS+=("provision-foundation")

if [[ -z "$ONLY" || "$ONLY" == "databases" ]]; then
  CURRENT_STEP="provision-databases"
  step "provision-databases"
  run "$SCRIPT_DIR/provision-databases.sh" "$ACTION"
  COMPLETED_STEPS+=("provision-databases")
fi
if [[ -z "$ONLY" || "$ONLY" == "functions" ]]; then
  CURRENT_STEP="provision-functions"
  step "provision-functions"
  run "$SCRIPT_DIR/provision-functions.sh" "$ACTION"
  CURRENT_STEP="publish-functions"
  step "publish-functions"
  run "$SCRIPT_DIR/publish-functions.sh"
  COMPLETED_STEPS+=("provision-functions + publish-functions")
fi
if [[ -z "$ONLY" || "$ONLY" == "eventgrid" ]]; then
  CURRENT_STEP="provision-eventgrid"
  step "provision-eventgrid"
  run "$SCRIPT_DIR/provision-eventgrid.sh" "$ACTION"
  COMPLETED_STEPS+=("provision-eventgrid")
fi
if [[ -z "$ONLY" || "$ONLY" == "containerapp" ]]; then
  CURRENT_STEP="provision-containerapp"
  step "provision-containerapp"
  run "$SCRIPT_DIR/provision-containerapp.sh" "$ACTION"
  CURRENT_STEP="publish-web"
  step "publish-web"
  run "$SCRIPT_DIR/publish-web.sh"
  COMPLETED_STEPS+=("provision-containerapp + publish-web")
fi
CURRENT_STEP=""
success "Provisioning complete. Outputs: $ROOT/.provision-outputs.json"
