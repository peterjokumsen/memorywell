#!/usr/bin/env bash
# Full deployment: shared resources first, then the environment.
# Passes the action through to both steps (e.g. `./deploy-all.sh what-if`).
# Fails fast: the environment step never runs if the shared step fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Logging helpers + env (BASE_NAME, ENVIRONMENT, ...).
source "$SCRIPT_DIR/common.sh"

# Validate args before touching Azure (mirrors deploy-shared.sh/deploy.sh).
ACTION="${1:-create}"
if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  error "$1 is not a valid action"
  echo "Usage: $0 [create|what-if]"
  exit 1
fi

init_command_log "deploy-all"

step "Deploying shared resources..."
if ! run "$SCRIPT_DIR/deploy-shared.sh" "$ACTION"; then
  error "Shared deployment failed; aborting before environment deployment."
  exit 1
fi

step "Deploying environment resources..."
run "$SCRIPT_DIR/deploy.sh" "$ACTION"

success "All deployments completed successfully."
