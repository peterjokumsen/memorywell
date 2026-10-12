ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Color helpers: auto-disabled when output is not a TTY or NO_COLOR is set,
# so piped/logged output stays plain. Use step/info/success/warn for stdout
# messaging; error goes to stderr. Never use these inside $(...) captures.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\e[0m'; C_BLUE=$'\e[34m'; C_GREEN=$'\e[32m'
  C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_CYAN=$'\e[36m'
else
  C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''
fi
step()    { printf '%b==>%b %s\n' "$C_BLUE" "$C_RESET" "$*"; }
info()    { printf '%b%s%b\n' "$C_CYAN" "$*" "$C_RESET"; }
success() { printf '%b%s%b\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()    { printf '%b%s%b\n' "$C_YELLOW" "$*" "$C_RESET"; }
error()   { printf '%b%s%b\n' "$C_RED" "$*" "$C_RESET" >&2; }

if [[ -f "$ROOT/.env" ]]; then
  set -o allexport; source "$ROOT/.env"; set +o allexport
  info "Loaded .env"
fi

: "${BASE_NAME:?set BASE_NAME in .env}"
: "${ENVIRONMENT:=dev}"
: "${LOCATION:?set LOCATION in .env}"
: "${SUBSCRIPTION_ID:?set SUBSCRIPTION_ID in .env}"

export RG_NAME="rg-${BASE_NAME}-${ENVIRONMENT}"

# Shared resource group + registry (created once by deploy-shared.sh, kept
# across teardowns). The registry name drops the environment suffix so one ACR
# serves every environment; `acr` prefix + stripped hyphens keep it valid and
# globally unique.
export SHARED_RG_NAME="rg-${BASE_NAME}-shared"
export SHARED_ACR_NAME="$(echo "acr${BASE_NAME}" | tr '[:upper:]' '[:lower:]' | tr -d '-')"

registry_name() { echo "$SHARED_ACR_NAME"; }
login_server() { echo "${SHARED_ACR_NAME}.azurecr.io"; }

# Subscription-deployment names must be unique per `az deployment sub create`
# run: re-using a name overwrites history and can confuse `sub show` output
# lookups. So each run gets a timestamped name
# (`<base>-<env>-YYYYmmdd-HHMMSS`), recorded in $LAST_DEPLOYMENT_FILE.
# Set REUSE_DEPLOYMENT=1 to re-run against the previous name (e.g. debugging
# a failed deployment) instead of minting a new one.
export LAST_DEPLOYMENT_FILE="${TMPDIR:-/tmp}/memorywell-${BASE_NAME}-${ENVIRONMENT}.deployment"
if [[ -n "${REUSE_DEPLOYMENT:-}" && -f "$LAST_DEPLOYMENT_FILE" ]]; then
  export DEPLOYMENT_NAME="$(cat "$LAST_DEPLOYMENT_FILE")"
else
  export DEPLOYMENT_NAME="${BASE_NAME}-${ENVIRONMENT}-$(date -u +%Y%m%d-%H%M%S)"
  printf '%s' "$DEPLOYMENT_NAME" > "$LAST_DEPLOYMENT_FILE"
fi

# Image tag is derived from the deployment timestamp so every `deploy.sh` run
# pushes a unique tag (`<env>-YYYYmmdd-HHMMSS`). Re-pushing the floating
# `api:<env>` tag alone does not change the Container App template string,
# so Container Apps mints no new revision; a unique tag per run guarantees
# revision 2+ on every `containerapp update`.
TIMESTAMP="${DEPLOYMENT_NAME##"${BASE_NAME}-${ENVIRONMENT}-"}"
export IMAGE_TAG="${ENVIRONMENT}-${TIMESTAMP}"

log_vars() {
  for kvp in "$@"; do
    printf '  %-16s %s' "${kvp%%=*}:" "${kvp#*=}"
      echo
  done
}
