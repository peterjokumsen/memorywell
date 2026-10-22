#!/usr/bin/env bash
# Container image build, push, and optional Container App update.
# Run after a successful Bicep deployment (provision-env.sh or provision-all.sh).
# Discovers containers under $ROOT (directories with Dockerfile), builds/pushes
# them with the specified tag (default: latest) plus a unique timestamp tag,
# and optionally updates Container Apps and runs health checks.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Parse arguments
ACTION="create"
BICEP_ONLY=0
TAG="latest"
UPDATE_APPS=0
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
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --update-apps)
      UPDATE_APPS=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--action create|what-if] [--bicep-only] [--tag TAG] [--update-apps]"
      echo "  --action ACTION      Deployment action: create (default) or what-if"
      echo "  --bicep-only         Stop after verifying Bicep outputs; skip build/push/update"
      echo "  --tag TAG            Docker tag to push (default: latest). Also pushes \$IMAGE_TAG."
      echo "  --update-apps        Update Container Apps and run health checks (default: off)"
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      echo "Usage: $0 [--action create|what-if] [--bicep-only] [--tag TAG] [--update-apps]" >&2
      exit 1
      ;;
  esac
done

if [[ "$ACTION" != "create" && "$ACTION" != "what-if" ]]; then
  error "$ACTION is not a valid action"
  echo "Usage: $0 [--action create|what-if] [--bicep-only] [--tag TAG] [--update-apps]" >&2
  exit 1
fi

if [[ "$ACTION" == "what-if" ]]; then
  success "What-if analysis completed. No changes were made."
  exit 0
fi

if [[ "$BICEP_ONLY" == "1" && "$ACTION" == "what-if" ]]; then
  error "--bicep-only is not compatible with --action what-if"
  exit 1
fi

if [[ "$BICEP_ONLY" == "1" ]]; then
  success "Bicep outputs verified. Stopping due to --bicep-only flag."
  success "Run the following manually to complete the container deployment:"
  success "  1. Build and push all containers: $0 --tag $TAG"
  if [[ "$UPDATE_APPS" == "1" ]]; then
    success "  2. Update container app: az containerapp update --name \$APP_NAME --resource-group $RG_NAME --image \$(login_server)/api:\$IMAGE_TAG"
    success "  3. Verify health: curl https://\$FQDN/health"
  fi
  exit 0
fi

if [[ -z "$TAG" ]]; then
  error "--tag requires a value"
  exit 1
fi

init_command_log "publish-containers"

# Get client IP and mint the timestamped deployment name + image tag
DEPLOYMENT_NAME="$(deployment_name)"
IMAGE_TAG="$(image_tag)"
export DEPLOYMENT_NAME IMAGE_TAG

# Set the subscription context for Azure CLI commands
run az account set --subscription "$SUBSCRIPTION_ID"

# --- Auto-discover containers under $ROOT ---
# A "container" is any directory directly under $ROOT that contains a Dockerfile
step "Discovering containers under $ROOT..."
CONTAINERS=()
while IFS= read -r -d '' dockerfile; do
  container_dir="$(dirname "$dockerfile")"
  # Only consider directories directly under $ROOT (one level deep)
  rel_path="${container_dir#$ROOT/}"
  if [[ "$rel_path" != */* ]]; then
    CONTAINERS+=("$rel_path")
  fi
done < <(find "$ROOT" -maxdepth 2 \( -name "Dockerfile" -o -name "dockerfile" \) -print0 2>/dev/null)

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
  warn "No containers discovered (no Dockerfile found in direct subdirectories of $ROOT)"
else
  success "Discovered ${#CONTAINERS[@]} container(s): ${CONTAINERS[*]}"
fi

# Build and push each discovered container
for container in "${CONTAINERS[@]}"; do
  # Derive image name from directory name
  # Special case: "functions" -> "memorywell-functions", others use directory name
  if [[ "$container" == "functions" ]]; then
    IMAGE_NAME="memorywell-functions"
  else
    IMAGE_NAME="$container"
  fi

  step "Building and pushing $IMAGE_NAME image to ACR..."
  # Push the user-specified tag (default: latest) + unique timestamp tag
  run az acr build -r "$(registry_name)" -t "$IMAGE_NAME:$TAG" -t "$IMAGE_NAME:$IMAGE_TAG" "$ROOT/$container"
done

# If --update-apps is not set, we're done after pushing images
if [[ "$UPDATE_APPS" == "0" ]]; then
  success "Container images built and pushed with tags: $TAG, $IMAGE_TAG"
  success "Run with --update-apps to update Container Apps and run health checks."
  exit 0
fi

# Verify the environment resource group exists
step "Checking resource group $RG_NAME..."
if ! RG_STATE=$(run_hide_stderr az group show --name "$RG_NAME" --query properties.provisioningState -o tsv); then
  error "Resource group $RG_NAME does not exist. Run provision-env.sh first."
  exit 1
fi
if [[ "$RG_STATE" == "Deleting" ]]; then
  error "Resource group $RG_NAME is still deleting."
  exit 1
fi

# Fetch Bicep deployment outputs (registry, loginServer, appName, fqdn)
step "Fetching Bicep deployment outputs..."
DEPLOYMENT_OUTPUTS="$(fetch_deployment_outputs "$DEPLOYMENT_NAME" \
  "[properties.outputs.registryName.value, properties.outputs.loginServer.value, properties.outputs.appName.value, properties.outputs.fqdn.value]" 4)" || exit 1
IFS=$'\t' read -r REGISTRY LOGIN_SERVER APP_NAME FQDN <<< "$DEPLOYMENT_OUTPUTS" || true

log_vars \
  "REGISTRY=$REGISTRY" \
  "LOGIN_SERVER=$LOGIN_SERVER" \
  "APP_NAME=$APP_NAME" \
  "FQDN=$FQDN"

if [[ "$(login_server)" != "$LOGIN_SERVER" ]]; then
  error "Login server mismatch"
  exit 1
fi

# --- Update Container Apps and health checks ---

# Update the API container app with the new image (timestamp tag guarantees new revision)
step "Deploying API container app..."
run az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RG_NAME" \
  --image "$LOGIN_SERVER/api:$IMAGE_TAG"

# Health check
step "Waiting for https://${FQDN}/health ..."
attempt=1
max_attempts=12 # ~60s: covers ACR pull + scale-from-zero on Consumption
until run curl -sSf --max-time 5 "https://${FQDN}/health" | jq; do
  if [[ "$attempt" -ge "$max_attempts" ]]; then
    error "Health check failed after $max_attempts attempts."
    exit 1
  fi
  warn "Attempt $attempt/$max_attempts failed, retrying in 5s..."
  sleep 5
  attempt=$((attempt + 1))
done
success "API is healthy at https://${FQDN}/health."

# Update Bruno dev environment with deployed FQDN
step "Updating Bruno dev environment..."
BRUNO_DEV_ENV="$ROOT/bruno/environments/dev.yml"
if [[ -f "$BRUNO_DEV_ENV" ]]; then
  # Update API base_url
  sed -i "s|value: https://<DEPLOYED_FQDN>|value: https://${FQDN}|" "$BRUNO_DEV_ENV"
  success "  Updated API base_url to https://${FQDN}"

  # Try to get function app name from Container Apps in the RG
  FUNC_APP_NAME=$(run az containerapp list -g "$RG_NAME" --query "[?contains(name, 'func') || contains(name, 'function')].name" -o tsv | head -n1)
  if [[ -n "$FUNC_APP_NAME" ]]; then
    FUNC_FQDN=$(run az containerapp show -n "$FUNC_APP_NAME" -g "$RG_NAME" --query properties.configuration.ingress.fqdn -o tsv)
    if [[ -n "$FUNC_FQDN" ]]; then
      sed -i "s|value: https://<FUNCTION_APP_NAME>.azurewebsites.net|value: https://${FUNC_FQDN}|" "$BRUNO_DEV_ENV"
      success "  Updated functions base_url to https://${FUNC_FQDN}"
    fi
  else
    warn "  No function Container App found in $RG_NAME; functions base_url left as placeholder"
  fi
else
  warn "  Bruno dev environment not found at $BRUNO_DEV_ENV"
fi

success "Container deployment completed successfully."
