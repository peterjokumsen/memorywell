# shellcheck shell=bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Logging backend (colour locally, GitHub Actions workflow commands in CI):
# defines step/info/success/warn/error/debug/group/endgroup. Override the pick
# with LOG_FORMAT=local|github. Both backends keep chatter off stdout, so
# `X="$(some_helper)"` captures stay data-only. Never call these inside a
# $(...) capture in the local backend either: info/step/success go to stdout
# there, and would be captured along with the result.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log.sh"

if [[ -f "$ROOT/.env" ]]; then
  set -o allexport; source "$ROOT/.env"; set +o allexport
  debug "Loaded .env"
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
SHARED_RG_NAME="rg-${BASE_NAME}-shared"
export SHARED_RG_NAME
SHARED_ACR_NAME="$(echo "acr${BASE_NAME}" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
export SHARED_ACR_NAME
# Key Vault name for this environment, and the single source of truth for it:
# deploy.sh/teardown.sh probe the vault by this name, and infra/main.bicepparam
# reads it back through readEnvironmentVariable('VAULT_NAME'), so the template
# never rebuilds the name from baseName/environment. Keep in mind the name is
# globally unique: changing BASE_NAME or ENVIRONMENT changes it, and a
# soft-deleted vault keeps the old name reserved until it is purged.
VAULT_NAME="kv-${BASE_NAME}-${ENVIRONMENT}"
export VAULT_NAME

registry_name() { echo "$SHARED_ACR_NAME"; }
login_server() { echo "${SHARED_ACR_NAME}.azurecr.io"; }

# Display name of the configured subscription (e.g. "My Subscription"), for log
# lines only. Queried lazily (explicit --subscription, so it never depends on
# the current `az account set` context) so sourcing this file stays cheap and
# never fails when logged out.
#
# At most ONE `az account show` per script run, however many times this is
# called: the name is cached in a file rather than a variable because every
# caller uses it inside a `$(...)` capture (log_vars arguments), and a variable
# set in a command substitution is discarded with the subshell. The cache is
# keyed by subscription id and deliberately outlives the run (a display name
# changes rarely, and the alternative is an `az` round-trip per log header);
# pass --refresh after renaming a subscription, or delete the file.
#   subscription_name             cached (queries on first use)
#   subscription_name --refresh   re-query and overwrite the cache
# Export SUBSCRIPTION_NAME to skip the `az` call entirely (CI does not need it).
export SUBSCRIPTION_NAME_FILE="${TMPDIR:-/tmp}/memorywell-subscription-name-${SUBSCRIPTION_ID}"
subscription_name() {
  local refresh=0
  if [[ "${1:-}" == "--refresh" ]]; then
    refresh=1
  elif [[ -n "${SUBSCRIPTION_NAME:-}" ]]; then
    printf '%s\n' "$SUBSCRIPTION_NAME"
    return 0
  fi
  if [[ "$refresh" -eq 1 || ! -s "$SUBSCRIPTION_NAME_FILE" ]]; then
    local name
    name="$(az account show --subscription "$SUBSCRIPTION_ID" --query name -o tsv 2>/dev/null || true)"
    printf '%s' "${name:-(unknown)}" > "$SUBSCRIPTION_NAME_FILE"
  fi
  printf '%s\n' "$(cat "$SUBSCRIPTION_NAME_FILE")"
}

# Subscription-deployment names must be unique per `az deployment sub create`
# run: re-using a name overwrites history and can confuse `sub show` output
# lookups. So each deployment gets a timestamped name
# (`<base>-<env>-YYYYmmdd-HHMMSS`), recorded in $LAST_DEPLOYMENT_FILE.
# Set REUSE_DEPLOYMENT=1 to re-run against the previous name (e.g. debugging
# a failed deployment) instead of minting a new one.
#
# Names are minted lazily via `deployment_name` (and `image_tag` below), not
# at source time: merely sourcing this file (e.g. deploy-all.sh, which never
# deploys directly) must not reserve a name in $LAST_DEPLOYMENT_FILE.
export LAST_DEPLOYMENT_FILE="${TMPDIR:-/tmp}/memorywell-${BASE_NAME}-${ENVIRONMENT}.deployment"
deployment_name() {
  if [[ -z "${DEPLOYMENT_NAME:-}" ]]; then
    if [[ -n "${REUSE_DEPLOYMENT:-}" && -f "$LAST_DEPLOYMENT_FILE" ]]; then
      DEPLOYMENT_NAME="$(cat "$LAST_DEPLOYMENT_FILE")"
    else
      DEPLOYMENT_NAME="${BASE_NAME}-${ENVIRONMENT}-$(date -u +%Y%m%d-%H%M%S)"
      printf '%s' "$DEPLOYMENT_NAME" > "$LAST_DEPLOYMENT_FILE"
    fi
    export DEPLOYMENT_NAME
  fi
  printf '%s\n' "$DEPLOYMENT_NAME"
}

# Image tag is derived from the deployment timestamp so every `deploy.sh` run
# pushes a unique tag (`<env>-YYYYmmdd-HHMMSS`). Re-pushing the floating
# `api:<env>` tag alone does not change the Container App template string,
# so Container Apps mints no new revision; a unique tag per run guarantees
# revision 2+ on every `containerapp update`.
image_tag() {
  deployment_name >/dev/null
  local dep="$DEPLOYMENT_NAME"
  printf '%s\n' "${ENVIRONMENT}-${dep##"${BASE_NAME}-${ENVIRONMENT}-"}"
}

log_vars() {
  # Two passes so the values align: first find the widest "key:", then print.
  # (A fixed width breaks as soon as a longer key like "Shared resource group"
  # shows up.) Lines go through `info` rather than a bare printf so the GitHub
  # backend turns each one into a notice instead of invisible plain output.
  local width=0 kvp key line
  for kvp in "$@"; do
    key="${kvp%%=*}:"
    if (( ${#key} > width )); then
      width=${#key}
    fi
  done
  for kvp in "$@"; do
    printf -v line '  %-*s %s' "$width" "${kvp%%=*}:" "${kvp#*=}"
    info "$line"
  done
}

# Command log: `init_command_log <name>` creates
# `$ROOT/logs/<name>-YYYYmmdd-HHMMSS.log` and sets COMMAND_LOG. `run` echoes
# the command (`+ az ...`) to stderr, appends it to the log, then executes it —
# with the command's stdout *and* stderr appended to the log as well, so the
# file is a full transcript of the run and not just a list of commands. The
# command's own output is never redirected away on the console: it still goes
# to stdout/stderr exactly as it would without `run`, which is what keeps
# `X=$(run az ...)` capturing only the command's stdout.
# Use `run` for every `az`/`curl` call, including inside `if` conditions and
# `$(...)` captures. When an error exit is an expected outcome (e.g. probing for
# a resource that may not exist yet), use `run_hide_stderr` (hides the command's
# stderr on the console, but still logs it) or `run_quiet` (hides stdout on the
# console too) instead of appending `2>/dev/null` to `run` — a redirect on `run`
# itself would swallow the `+` trace as well.
#
# Implementation notes: stdout is piped through `tee` (the pipeline's first
# status is the command's, so exit codes survive), while stderr is teed through
# a process substitution so the two streams never merge — merging them would
# splice stderr text into a caller's `$(...)` capture. Both tees append to the
# same file; those writes are line-sized and O_APPEND, so they interleave rather
# than corrupt. CAVEAT: a process substitution is not waited for, so a burst of
# stderr can appear in the log just after the next command's trace line.
export COMMAND_LOG="${COMMAND_LOG:-}"
init_command_log() {
  local name="${1:?usage: init_command_log <name>}"
  mkdir -p "$ROOT/logs"
  COMMAND_LOG="$ROOT/logs/${name}-$(date -u +%Y%m%d-%H%M%S).log"
  export COMMAND_LOG
  debug "Command log: $COMMAND_LOG"
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

# _log_stderr: tees a command's stderr into the command log while leaving it on
# the console's stderr. Process substitution (rather than `2>&1`) keeps stderr
# out of a caller's `$(...)` capture.
_log_stderr() {
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    tee -a "$COMMAND_LOG" >&2
  else
    cat >&2
  fi
}

run() {
  log_cmd "$@"
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    "$@" 2> >(_log_stderr) | tee -a "$COMMAND_LOG"
    return "${PIPESTATUS[0]}"
  fi
  "$@"
}

# Hides the command's stderr on the console but keeps it in the log: the
# "resource does not exist" probes rely on it, and a failed probe is exactly
# what you want to find in the transcript later.
run_hide_stderr() {
  log_cmd "$@"
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    "$@" 2>> "$COMMAND_LOG" | tee -a "$COMMAND_LOG"
    return "${PIPESTATUS[0]}"
  fi
  "$@" 2>/dev/null
}

run_quiet() {
  log_cmd "$@"
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    "$@" >> "$COMMAND_LOG" 2>&1
    return $?
  fi
  "$@" >/dev/null 2>&1
}

# fetch_deployment_outputs <deployment-name> <query> <expected-fields> [max-attempts [delay-secs]]:
# Polls `az deployment sub show` until the TSV query returns all
# <expected-fields> non-empty values, then prints them tab-separated.
# Subscription outputs can lag the Succeeded state (ARM eventual
# consistency), and `az -o tsv` drops null columns entirely (a 2-field query
# with one value missing returns just "value"). Array elements may also come
# back newline-separated instead of tab-separated depending on CLI
# version/shape, so the output is flattened to tabs before counting.
# Fails (after dumping properties.outputs) when the outputs never fill in.
# Capture with:
#   OUT="$(fetch_deployment_outputs "$NAME" "<query>" 2)" || exit 1
# No group/endgroup around the retry loop, and no redirection tricks: both
# backends already keep chatter off stdout (see log-ghactions.sh), so the
# capture below picks up only the tab-separated result.
fetch_deployment_outputs() {
  local deployment_name="${1:?usage: fetch_deployment_outputs <deployment-name> <query> <expected-fields> [max-attempts [delay-secs]]}"
  local query="${2:?usage: fetch_deployment_outputs <deployment-name> <query> <expected-fields> [max-attempts [delay-secs]]}"
  local expected_fields="${3:?usage: fetch_deployment_outputs <deployment-name> <query> <expected-fields> [max-attempts [delay-secs]]}"
  local max_attempts="${4:-10}"
  local delay="${5:-10}"
  local attempt=1 out flat has_empty field
  local -a fields
  while true; do
    out="$(run_hide_stderr az deployment sub show --name "$deployment_name" --query "$query" -o tsv || true)"
    # Flatten: TSV array elements arrive tab- or newline-separated (CLI
    # version/shape dependent); callers always read a single tab-joined row.
    flat="$(printf '%s' "$out" | tr -d '\r' | tr '\n' '\t')"
    if [[ -n "$flat" ]]; then
      has_empty=0
      IFS=$'\t' read -ra fields <<< "$flat" || true
      # az -o tsv drops null columns, so a partial row has fewer fields, not
      # empty ones: require the full column count first.
      if [[ "${#fields[@]}" -ne "$expected_fields" ]]; then
        has_empty=1
      else
        for field in ${fields[@]+"${fields[@]}"}; do
          if [[ -z "$field" ]]; then
            has_empty=1
            break
          fi
        done
        # read -ra drops trailing empty fields, so also reject leading,
        # trailing, or doubled tabs explicitly (empty first/last/middle col).
        if [[ "$flat" == *$'\t\t'* || "$flat" == *$'\t' || "$flat" == $'\t'* ]]; then
          has_empty=1
        fi
      fi
      if [[ "$has_empty" -eq 0 ]]; then
        printf '%s\n' "$flat"
        return 0
      fi
    fi
    if [[ "$attempt" -ge "$max_attempts" ]]; then
      error "Deployment $deployment_name is missing expected outputs after $max_attempts checks."
      run_hide_stderr az deployment sub show --name "$deployment_name" \
        --query properties.outputs -o json || true
      return 1
    fi
    warn "Attempt $attempt/$max_attempts: outputs not yet available, retrying in ${delay}s..."
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

# group_exists <rg-name>: prints `true`/`false`. Exits nonzero (after an
# `error` line) when `az` itself fails or prints something unexpected, so
# callers never mistake an outage for absence. Capture with an explicit guard:
#   RG_EXISTS="$(group_exists "$RG_NAME")" || exit 1
group_exists() {
  local rg="$1" out
  if ! out=$(run az group exists --name "$rg" -o tsv); then
    error "Could not check whether resource group $rg exists (see above)."
    return 1
  fi
  case "$out" in
    true|false) printf '%s\n' "$out" ;;
    *)
      error "Unexpected 'az group exists' output for $rg: $out"
      return 1
      ;;
  esac
}

# vault_is_live: succeeds when the vault named by the global VAULT_NAME exists
# (not deleted). vault_is_soft_deleted: succeeds when a soft-deleted vault of
# that name is waiting for purge. Both hide the command's stderr: absence is
# an expected outcome for these probes.
vault_is_live() {
  run_hide_stderr az keyvault show --name "$VAULT_NAME" >/dev/null
}

vault_is_soft_deleted() {
  run_hide_stderr az keyvault list-deleted --query "[?name=='$VAULT_NAME'].name" -o tsv | grep -q "$VAULT_NAME"
}
