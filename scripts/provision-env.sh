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
run az account set --subscription "$SUBSCRIPTION_ID"
run "$SCRIPT_DIR/provision-foundation.sh" "$ACTION"
if [[ -z "$ONLY" || "$ONLY" == "databases" ]]; then run "$SCRIPT_DIR/provision-databases.sh" "$ACTION"; fi
if [[ -z "$ONLY" || "$ONLY" == "functions" ]]; then
  run "$SCRIPT_DIR/publish-functions.sh"
  run "$SCRIPT_DIR/provision-functions.sh" "$ACTION"
fi
if [[ -z "$ONLY" || "$ONLY" == "eventgrid" ]]; then run "$SCRIPT_DIR/provision-eventgrid.sh" "$ACTION"; fi
if [[ -z "$ONLY" || "$ONLY" == "containerapp" ]]; then run "$SCRIPT_DIR/provision-containerapp.sh" "$ACTION"; fi
success "Provisioning complete. Outputs: $ROOT/.provision-outputs.json"
