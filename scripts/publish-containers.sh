#!/usr/bin/env bash
# Container image build, push, and optional Container App update.
# Run after a successful Bicep deployment (provision-env.sh or provision-all.sh).
#
# A container is a directory directly under $ROOT that carries a container.json
# manifest. The manifest is the source of truth for how the directory maps onto
# an image and (optionally) a Container App:
#
#   {
#     "image": "api",              // ACR repository name (default: directory name)
#     "context": ".",              // build context, relative to the manifest (default: ".")
#     "dockerfile": "Dockerfile",  // relative to the context (default: "Dockerfile")
#     "appRole": "",               // "" = primary app, "<role>" = ca-<base>-<env>-<role>,
#                                  // omitted = no Container App update
#     "healthPath": "/health",     // GET <fqdn><path> after update; omit to skip
#     "brunoVar": "api_url"        // Bruno dev env variable to point at the FQDN
#   }
#
# Dockerfiles without a manifest are reported and skipped, so a new directory is
# never published by accident. Builds push the requested tag (default: latest)
# plus a unique timestamp tag; --update-apps rolls every matching app to the
# timestamp tag, waits for its health endpoint, and refreshes Bruno.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=_bruno.sh
source "${_SCRIPTS_DIR}/_bruno.sh"

# Parse arguments
TAG="latest"
UPDATE_APPS=0
LIST_ONLY=0
DRY_RUN=0
ONLY=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --update-apps)
      UPDATE_APPS=1
      shift
      ;;
    --only)
      ONLY+=("${2:-}")
      shift 2
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    --dry-run | --what-if)
      DRY_RUN=1
      shift
      ;;
    -h | --help)
      echo "Usage: $0 [--tag TAG] [--only NAME] [--update-apps] [--list] [--dry-run]"
      echo "  --tag TAG        Docker tag to push (default: latest). Also pushes \$IMAGE_TAG."
      echo "  --only NAME      Only publish this container (directory or image name; repeatable)"
      echo "  --update-apps    Update Container Apps, run health checks, refresh Bruno (default: off)"
      echo "  --list           Print the resolved containers and exit (no Azure calls)"
      echo "  --dry-run        Print the build/update plan and exit (no Azure calls)"
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      echo "Usage: $0 [--tag TAG] [--only NAME] [--update-apps] [--list] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TAG" ]]; then
  error "--tag requires a value"
  exit 1
fi

init_command_log "publish-containers"

# Unique per-run tag: Container Apps only mints a new revision when the image
# string changes, so re-pushing a floating tag alone would leave the old
# revision running. Publish runs have no deployment of their own to borrow a
# timestamp from, so mint one here (the recorded deployment is only read when
# --update-apps needs its outputs).
IMAGE_TAG="${ENVIRONMENT}-$(date -u +%Y%m%d-%H%M%S)-publish"
export IMAGE_TAG

# --- Discover containers (manifest-driven) ---
# A "container" is a directory directly under $ROOT with a container.json.
# Dockerfiles alone are deliberately not enough: silently picking up a stray
# Dockerfile (web/, a scratch directory) is how a publish script builds the
# wrong thing.
step "Discovering containers under $ROOT..."

DIRS=()
IMAGES=()
CONTEXTS=()
DOCKERFILES=()
APP_ROLES=()
HEALTH_PATHS=()
BRUNO_VARS=()

declare -A SEEN_IMAGES=()
shopt -s nullglob

for manifest in "$ROOT"/*/container.json; do
  container_dir="$(dirname "$manifest")"
  name="$(basename "$container_dir")"

  if ! fields_json="$(jq -er '
    [
      (.image // ""),
      (.context // "."),
      (.dockerfile // "Dockerfile"),
      (.appRole // "-"),
      (.healthPath // ""),
      (.brunoVar // "")
    ] | .[]
  ' "$manifest" 2>/dev/null)"; then
    error "Invalid container manifest: ${manifest#"$ROOT"/}"
    exit 1
  fi
  # One field per line: reading a tab-separated line with IFS=$'\t' collapses
  # empty fields, which silently shifts every field after the first gap.
  mapfile -t fields <<< "$fields_json"
  if [[ ${#fields[@]} -ne 6 ]]; then
    error "Invalid container manifest: ${manifest#"$ROOT"/}"
    exit 1
  fi
  image="${fields[0]}"
  context="${fields[1]}"
  dockerfile="${fields[2]}"
  app_role="${fields[3]}"
  health_path="${fields[4]}"
  bruno_var="${fields[5]}"

  # Defaults keep a minimal manifest (`{}`) working without hardcoding an image
  # name in the script.
  image="${image:-$name}"
  context="${context:-.}"
  dockerfile="${dockerfile:-Dockerfile}"

  # --- Validate before anything reaches Azure ---
  if [[ ! "$image" =~ ^[a-z0-9]+([._/-][a-z0-9]+)*$ ]]; then
    error "Invalid image name '$image' in ${manifest#"$ROOT"/} (lowercase alphanumerics, '.', '_', '-', '/')"
    exit 1
  fi
  if [[ -n "${SEEN_IMAGES[$image]:-}" ]]; then
    error "Duplicate image '$image' in ${manifest#"$ROOT"/} and ${SEEN_IMAGES[$image]}"
    exit 1
  fi
  SEEN_IMAGES["$image"]="$name"

  if [[ "$app_role" != "-" && -n "$app_role" && ! "$app_role" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    error "Invalid appRole '$app_role' in ${manifest#"$ROOT"/}"
    exit 1
  fi
  if [[ -n "$health_path" && ! "$health_path" =~ ^/[A-Za-z0-9/._-]*$ ]]; then
    error "Invalid healthPath '$health_path' in ${manifest#"$ROOT"/} (must start with '/')"
    exit 1
  fi
  if [[ -n "$bruno_var" && ! "$bruno_var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    error "Invalid brunoVar '$bruno_var' in ${manifest#"$ROOT"/}"
    exit 1
  fi

  if ! context_path="$(cd "$container_dir/$context" 2>/dev/null && pwd)"; then
    error "Build context '$context' does not exist in ${manifest#"$ROOT"/}"
    exit 1
  fi
  if [[ "$context_path" != "$ROOT" && "$context_path" != "$ROOT"/* ]]; then
    error "Build context '$context' escapes $ROOT in ${manifest#"$ROOT"/}"
    exit 1
  fi
  if [[ ! -f "$context_path/$dockerfile" ]]; then
    error "Dockerfile '$dockerfile' not found in ${manifest#"$ROOT"/}"
    exit 1
  fi

  # --- Optional filter ---
  if [[ ${#ONLY[@]} -gt 0 ]]; then
    matched=0
    for want in "${ONLY[@]}"; do
      if [[ "$want" == "$name" || "$want" == "$image" ]]; then
        matched=1
      fi
    done
    if [[ "$matched" == "0" ]]; then
      continue
    fi
  fi

  DIRS+=("$name")
  IMAGES+=("$image")
  CONTEXTS+=("$context_path")
  DOCKERFILES+=("$dockerfile")
  APP_ROLES+=("$app_role")
  HEALTH_PATHS+=("$health_path")
  BRUNO_VARS+=("$bruno_var")
done

# Report Dockerfiles that no manifest claims, so nothing is silently ignored.
for dockerfile in "$ROOT"/*/[Dd]ockerfile "$ROOT"/*/Dockerfile.*; do
  container_dir="$(dirname "$dockerfile")"
  if [[ ! -f "$container_dir/container.json" ]]; then
    warn "  Ignoring ${dockerfile#"$ROOT"/}: no container.json manifest"
  fi
done

if [[ ${#ONLY[@]} -gt 0 && ${#DIRS[@]} -eq 0 ]]; then
  error "No container matched: ${ONLY[*]}"
  error "Available: $(for m in "$ROOT"/*/container.json; do basename "$(dirname "$m")"; done | tr '\n' ' ')"
  exit 1
fi

if [[ ${#DIRS[@]} -eq 0 ]]; then
  error "No containers discovered (no container.json under a direct subdirectory of $ROOT)"
  exit 1
fi

success "Discovered ${#DIRS[@]} container(s): ${DIRS[*]}"

# Human-readable plan, also used by --list/--dry-run.
print_plan() {
  printf '  %-12s %-22s %-18s %-22s %-14s %s\n' \
    "CONTAINER" "IMAGE" "DOCKERFILE" "APP" "HEALTH" "BRUNO VAR"
  local i
  for i in "${!DIRS[@]}"; do
    local app
    app="$(app_name_for_role "${APP_ROLES[$i]}")"
    printf '  %-12s %-22s %-18s %-22s %-14s %s\n' \
      "${DIRS[$i]}" \
      "${IMAGES[$i]}" \
      "${DOCKERFILES[$i]}" \
      "${app:-<none>}" \
      "${HEALTH_PATHS[$i]:-<none>}" \
      "${BRUNO_VARS[$i]:-<none>}"
  done
}

# Container Apps are named by Bicep convention: the primary app has no suffix,
# every other app ends in its role. Keeping this in one place means the manifest
# never hardcodes an environment-specific app name.
app_name_for_role() {
  local role="${1:-}"
  if [[ "$role" == "-" ]]; then
    return 0
  fi
  if [[ -z "$role" ]]; then
    printf 'ca-%s-%s' "$BASE_NAME" "$ENVIRONMENT"
  else
    printf 'ca-%s-%s-%s' "$BASE_NAME" "$ENVIRONMENT" "$role"
  fi
}

if [[ "$LIST_ONLY" == "1" ]]; then
  print_plan
  exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
  print_plan
  for i in "${!DIRS[@]}"; do
    echo "  (cd ${CONTEXTS[$i]} && az acr build -r $(registry_name) --file ${DOCKERFILES[$i]} \\"
    echo "    -t ${IMAGES[$i]}:$TAG -t ${IMAGES[$i]}:$IMAGE_TAG .)"
  done
  exit 0
fi

# Set the subscription context for Azure CLI commands
run az account set --subscription "$SUBSCRIPTION_ID"

# --- Build and push each container ---
for i in "${!DIRS[@]}"; do
  image="${IMAGES[$i]}"

  step "Building and pushing $image image to ACR (context: ${CONTEXTS[$i]#"$ROOT"/})..."
  # --file is resolved against the build context, so run from the context and
  # pass "." rather than an absolute Dockerfile path.
  (
    cd "${CONTEXTS[$i]}"
    run az acr build -r "$(registry_name)" \
      --file "${DOCKERFILES[$i]}" \
      -t "$image:$TAG" \
      -t "$image:$IMAGE_TAG" \
      .
  )
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

# Fetch Bicep deployment outputs (registry + login server) from the deployment
# recorded by provision-env.sh. Reading it (instead of minting a new name)
# matters: this script renders no Bicep, so a freshly minted name would have no
# outputs to read.
if [[ ! -f "$LAST_DEPLOYMENT_FILE" ]]; then
  error "No recorded deployment ($LAST_DEPLOYMENT_FILE). Run provision-env.sh first."
  exit 1
fi
DEPLOYMENT_NAME="$(cat "$LAST_DEPLOYMENT_FILE")"
export DEPLOYMENT_NAME

step "Fetching Bicep deployment outputs..."
DEPLOYMENT_OUTPUTS="$(fetch_deployment_outputs "$DEPLOYMENT_NAME" \
  "[properties.outputs.registryName.value, properties.outputs.loginServer.value]" 2)" || exit 1
IFS=$'\t' read -r REGISTRY LOGIN_SERVER <<< "$DEPLOYMENT_OUTPUTS" || true

log_vars \
  "REGISTRY=$REGISTRY" \
  "LOGIN_SERVER=$LOGIN_SERVER"

if [[ "$(login_server)" != "$LOGIN_SERVER" ]]; then
  error "Login server mismatch"
  exit 1
fi

# --- Update Container Apps, health checks, Bruno ---

# wait_for_health <url> [max_attempts]
wait_for_health() {
  local url="$1"
  local max_attempts="${2:-12}" # ~60s: covers ACR pull + scale-from-zero on Consumption
  local attempt=1
  step "Waiting for $url ..."
  until run curl -sSf --max-time 5 -o /dev/null "$url"; do
    if [[ "$attempt" -ge "$max_attempts" ]]; then
      error "Health check failed after $max_attempts attempts: $url"
      return 1
    fi
    warn "  Attempt $attempt/$max_attempts failed, retrying in 5s..."
    sleep 5
    attempt=$((attempt + 1))
  done
  success "  Healthy: $url"
}

BRUNO_DEV_ENV="$ROOT/bruno/environments/dev.yml"
BRUNO_UPDATED=0

for i in "${!DIRS[@]}"; do
  app_role="${APP_ROLES[$i]}"
  if [[ "$app_role" == "-" ]]; then
    continue
  fi

  app_name="$(app_name_for_role "$app_role")"
  if ! APP_FQDN=$(run_hide_stderr az containerapp show \
    --name "$app_name" \
    --resource-group "$RG_NAME" \
    --query properties.configuration.ingress.fqdn -o tsv) || [[ -z "$APP_FQDN" ]]; then
    warn "  Container App $app_name not found or has no ingress; skipping ${IMAGES[$i]}"
    continue
  fi

  step "Deploying $app_name ($LOGIN_SERVER/${IMAGES[$i]}:$IMAGE_TAG)..."
  run az containerapp update \
    --name "$app_name" \
    --resource-group "$RG_NAME" \
    --image "$LOGIN_SERVER/${IMAGES[$i]}:$IMAGE_TAG"

  if [[ -n "${HEALTH_PATHS[$i]}" ]]; then
    wait_for_health "https://${APP_FQDN}${HEALTH_PATHS[$i]}"
  fi

  bruno_var="${BRUNO_VARS[$i]}"
  if [[ -n "$bruno_var" ]]; then
    if [[ -f "$BRUNO_DEV_ENV" ]]; then
      if bruno_set_var "$BRUNO_DEV_ENV" "$bruno_var" "https://${APP_FQDN}"; then
        success "  Bruno ${bruno_var} -> https://${APP_FQDN}"
        BRUNO_UPDATED=1
      else
        warn "  Bruno variable '$bruno_var' not found in ${BRUNO_DEV_ENV#"$ROOT"/}"
      fi
    else
      warn "  Bruno dev environment not found at ${BRUNO_DEV_ENV#"$ROOT"/}"
    fi
  fi
done

if [[ "$BRUNO_UPDATED" == "1" ]]; then
  success "Bruno dev environment updated."
fi

success "Container deployment completed successfully."
