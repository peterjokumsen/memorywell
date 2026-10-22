#!/usr/bin/env bash
# Full deployment: shared resources first, then the environment.
# Passes the action through to both steps (e.g. `./provision-all.sh --action what-if`).
# Fails fast: the environment step never runs if the shared step fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Logging helpers + env (BASE_NAME, ENVIRONMENT, ...).
source "$SCRIPT_DIR/common.sh"

# Parse arguments
ACTION="create"
BICEP_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --bicep-only)
      BICEP_ONLY=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--action create|what-if] [--bicep-only]"
      echo "  --action ACTION      Deployment action: create (default) or what-if"
      echo "  --bicep-only         Stop after Bicep deployments; skip post-deployment steps"
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      echo "Usage: $0 [--action create|what-if] [--bicep-only]" >&2
      exit 1
      ;;
  esac
done

if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  error "$ACTION is not a valid action"
  echo "Usage: $0 [--action create|what-if] [--bicep-only]" >&2
  exit 1
fi

if [[ "$BICEP_ONLY" == "1" && "$ACTION" == "what-if" ]]; then
  error "--bicep-only is not compatible with --action what-if"
  exit 1
fi

init_command_log "provision-all"

step "Provisioning shared resources..."
shared_args=("--action" "$ACTION")
if [[ "$BICEP_ONLY" == "1" ]]; then
  shared_args+=("--bicep-only")
fi
if ! run "$SCRIPT_DIR/provision-shared.sh" "${shared_args[@]}"; then
  error "Shared deployment failed; aborting before environment deployment."
  exit 1
fi

if [[ "$BICEP_ONLY" == "0" ]]; then
  step "Deploying container images and updating Container Apps..."
  container_args=("--action" "$ACTION" "--update-apps")
  run "$SCRIPT_DIR/publish-containers.sh" "${container_args[@]}"
fi

step "Provisioning environment resources..."
env_args=("--action" "$ACTION")
if [[ "$BICEP_ONLY" == "1" ]]; then
  env_args+=("--bicep-only")
fi
run "$SCRIPT_DIR/povision-env.sh" "${env_args[@]}"

success "All deployments completed successfully."
