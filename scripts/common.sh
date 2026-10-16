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

# Display name of the configured subscription (e.g. "My Subscription").
# Queried lazily (explicit --subscription, so it never depends on the current
# `az account set` context) so sourcing this file stays cheap and never fails
# when logged out; callers use it for log lines only.
subscription_name() {
  az account show --subscription "$SUBSCRIPTION_ID" --query name -o tsv 2>/dev/null \
    || echo "(unknown)"
}

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
  # Two passes so the values align: first find the widest "key:", then print.
  # (A fixed width breaks as soon as a longer key like "Shared resource group"
  # shows up.)
  local width=0 kvp key
  for kvp in "$@"; do
    key="${kvp%%=*}:"
    if (( ${#key} > width )); then
      width=${#key}
    fi
  done
  for kvp in "$@"; do
    printf '  %-*s %s\n' "$width" "${kvp%%=*}:" "${kvp#*=}"
  done
}

# Command log: `init_command_log <name>` creates
# `$ROOT/logs/<name>-YYYYmmdd-HHMMSS.log` and sets COMMAND_LOG. `run` echoes
# the command (`+ az ...`) to stderr, appends it to the log, then executes it.
# Logging goes to stderr (not stdout) so `X=$(run az ...)` still captures only
# the command's own output. Use `run` for every `az`/`curl` call, including
# inside `if` conditions and `$(...)` captures.
export COMMAND_LOG="${COMMAND_LOG:-}"
init_command_log() {
  local name="${1:?usage: init_command_log <name>}"
  mkdir -p "$ROOT/logs"
  COMMAND_LOG="$ROOT/logs/${name}-$(date -u +%Y%m%d-%H%M%S).log"
  export COMMAND_LOG
  info "Command log: $COMMAND_LOG"
}

# _join_quoted: shell-quote each arg (%q) so the logged line is copy-pasteable.
_join_quoted() {
  local out="" a piece
  for a in "$@"; do
    piece=$(printf '%q' "$a")
    if [[ -z "$out" ]]; then
      out="$piece"
    else
      out="$out $piece"
    fi
  done
  printf '%s' "$out"
}

log_cmd() {
  local cmd
  cmd=$(_join_quoted "$@")
  printf '+ %s\n' "$cmd" >&2
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    printf '+ %s\n' "$cmd" >> "$COMMAND_LOG"
  fi
}

run() {
  log_cmd "$@"
  "$@"
}
