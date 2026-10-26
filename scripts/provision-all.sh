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
DEPLOYMENT_MODE="all"
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
    --deployment-mode)
      DEPLOYMENT_MODE="${2:-}"
      case "$DEPLOYMENT_MODE" in
        "all" | "container-apps" | "databases" | "skip-redis")
          shift 2
          ;;
        *)
          error "Unknown --deployment-mode: $1"
          echo "Expected: [all|container-apps|databases|skip-redis]"
          exit 1
          ;;
      esac
      ;;
    -h|--help)
      echo "Usage: $0 [--action create|what-if] [--bicep-only] [--deployment-mode all|container-apps|databases|skip-redis]"
      echo "  --action ACTION      Deployment action: create (default) or what-if"
      echo "  --bicep-only         Stop after Bicep deployments; skip post-deployment steps"
      echo "  --deployment-mode    Select mode of deployment for environment resource group"
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
  step "Publishing containers..."
  # publish-containers.sh renders no Bicep, so --action does not apply.
  run "$SCRIPT_DIR/publish-containers.sh"
fi

step "Provisioning environment resources..."
env_args=("--action" "$ACTION" "--deployment-mode" "$DEPLOYMENT_MODE")
if [[ "$BICEP_ONLY" == "1" ]]; then
  env_args+=("--bicep-only")
fi
run "$SCRIPT_DIR/provision-env.sh" "${env_args[@]}"

success "All deployments completed successfully."
