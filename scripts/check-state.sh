#!/usr/bin/env bash
# Check provisioning state of every resource deployed by the Bicep templates.
# Read-only: runs every probe first (each `step`/`+` line goes to stderr), then
# presents one consolidated report on stdout using the standard step/info/
# success/warn/error helpers, colour-coded per state. Exits 0 when everything is
# Succeeded (or nothing is deployed yet), 1 when anything is missing a
# Succeeded state.
set -euo pipefail

# prepare environment variables
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Usage: check-state.sh [--env-only] [--shared-only]
#   Default checks both resource groups. Flags limit the check to one side
#   (e.g. --shared-only after deploy-shared.sh, --env-only after deploy.sh).
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [--env-only] [--shared-only]"
  exit 0
fi
CHECK_ENV=1
CHECK_SHARED=1
for arg in "$@"; do
  case "$arg" in
    --env-only) CHECK_SHARED=0 ;;
    --shared-only) CHECK_ENV=0 ;;
    *)
      error "Unknown argument: $arg"
      echo "Usage: $0 [--env-only] [--shared-only]" >&2
      exit 2
      ;;
  esac
done

init_command_log "check-state"

step "Setting subscription..."
run az account set --subscription "$SUBSCRIPTION_ID"

OVERALL=0

# Indented report helpers: the plain common.sh printers take a ready-made
# message, so prefixing with two spaces keeps report lines visually nested
# under their `step` heading (including in logs, where colour is off).
p_step()    { step "  $*"; }
p_info()    { info "  $*"; }
p_success() { success "  $*"; }
p_warn()    { warn "  $*"; }
p_error()   { error "  $*"; }

# report_state <state> <message>: prints <message> through the helper matching
# <state>, so a failed deployment reads red and a succeeded one green instead of
# every line looking the same.
report_state() {
  local state="$1" message="$2"
  case "$state" in
    Succeeded) p_success "$message" ;;
    Failed | Canceled) p_error "$message" ;;
    absent) p_info "$message" ;;
    n/a) p_info "$message" ;;
    *) p_warn "$message" ;;
  esac
}

# Collected results, keyed by group label ("environment" / "shared").
declare -A GROUP_RG_STATE
declare -A GROUP_RES_TEXT
declare -A GROUP_DEP_TEXT

# check_group <rg-name> <label>: collects the RG state, the per-resource
# provisioningState (fetched individually with `az resource show`, since the
# list embedding is not authoritative for every type) and the latest RG-scope
# deployments. `az resource list` keeps this generic: new Bicep modules show up
# with no script change. Resources without a provisioningState field (e.g. role
# assignments, managed identities) report n/a and are excluded from the health
# check.
#
# The state query uses the CLI's null-coalescing `||`: `properties.provisioningState`
# is the canonical ARM location (ACR, Key Vault, Log Analytics, Container Apps,
# managed environments all use it), while a handful of legacy/older types only
# expose the top-level `provisioningState`. The fallback covers both in one call,
# and still yields empty output — reported as n/a — when neither exists.
check_group() {
  local rg="$1"
  local label="$2"
  local rg_state entries id name state bad=0

  step "Checking resource group $rg ($label)..."
  if rg_state=$(run_hide_stderr az group show --name "$rg" --query properties.provisioningState -o tsv); then
    [[ "$rg_state" == "Succeeded" ]] || OVERALL=1
  else
    GROUP_RG_STATE[$label]="absent"
    GROUP_RES_TEXT[$label]=""
    GROUP_DEP_TEXT[$label]=""
    return 0
  fi
  GROUP_RG_STATE[$label]="$rg_state"

  step "Fetching resource states in $rg ($label)..."
  if ! entries=$(run az resource list --resource-group "$rg" --query "sort_by(@, &name)[].{n:name, i:id}" -o tsv); then
    OVERALL=1
    GROUP_RES_TEXT[$label]="could not list resources in $rg"
  elif [[ -z "$entries" ]]; then
    GROUP_RES_TEXT[$label]="(no resources)"
  else
    local res_text=""
    while IFS=$'\t' read -r name id; do
      [[ -z "$name" ]] && continue
      state=$(run_hide_stderr az resource show --ids "$id" \
        --query "properties.provisioningState || provisioningState" -o tsv || true)
      # `||` yields empty when the type has neither field; older CLI versions
      # can also print a bare None for a scalar null, so normalise both to n/a
      # rather than reporting a bogus non-Succeeded state.
      state="${state:-n/a}"
      [[ "$state" == "None" || "$state" == "null" ]] && state="n/a"
      [[ -z "$res_text" ]] || res_text="$res_text"$'\n'
      res_text="$res_text$name"$'\t'"$state"
      if [[ "$state" != "Succeeded" && "$state" != "n/a" ]]; then
        bad=1
      fi
    done <<< "$entries"
    [[ "$bad" == "0" ]] || OVERALL=1
    GROUP_RES_TEXT[$label]="$res_text"
  fi

  step "Fetching latest deployments in $rg ($label)..."
  if deploy_rows=$(run az deployment group list --resource-group "$rg" \
      --query "sort_by(@, &properties.timestamp)[].{n:name, t:properties.timestamp, s:properties.provisioningState}" \
      -o tsv | tail -n 3); then
    local dep_text="" latest=""
    while IFS=$'\t' read -r name timestamp state; do
      [[ -z "$name" ]] && continue
      state="${state:-unknown}"
      [[ -z "$dep_text" ]] || dep_text="$dep_text"$'\n'
      dep_text="$dep_text$name"$'\t'"$timestamp"$'\t'"$state"
      latest="$state"
    done <<< "$deploy_rows"
    # A failed latest run fails the check even when the live resources still
    # look healthy.
    [[ -z "$latest" || "$latest" == "Succeeded" ]] || OVERALL=1
    GROUP_DEP_TEXT[$label]="$dep_text"
  else
    OVERALL=1
    GROUP_DEP_TEXT[$label]="could not list deployments in $rg"
  fi
}

# fetch_sub_deployments <name-prefix>: stores the latest 3 subscription
# deployments whose name starts with <name-prefix> in the global SUB_ROWS and
# folds the newest one's state into OVERALL. Returns 1 only when the listing
# itself failed; an empty result is a valid "nothing deployed yet" answer and
# must stay green.
fetch_sub_deployments() {
  local prefix="$1"
  local latest
  if ! sub_rows=$(run az deployment sub list \
      --query "sort_by(@, &properties.timestamp)[?starts_with(name, '${prefix}')].{n:name, t:properties.timestamp, s:properties.provisioningState}" \
      -o tsv | tail -n 3); then
    OVERALL=1
    SUB_ROWS=""
    return 1
  fi
  SUB_ROWS="$sub_rows"
  if [[ -n "$sub_rows" ]]; then
    latest="$(printf '%s\n' "$sub_rows" | tail -n 1 | cut -f3)"
    [[ -z "$latest" || "$latest" == "Succeeded" ]] || OVERALL=1
  fi
  return 0
}

# report_rows <block> <deployment-rows>: prints one collected block as indented
# report lines. A block is either empty ("nothing to show"), an informational
# marker set by check_group ("(no resources)"), a failure marker ("could not
# list ..."), or tab-separated rows (name + state, or name + timestamp + state
# when <deployment-rows> is 1). Only real rows go through report_state, so
# markers never pick up a state colour.
report_rows() {
  local block="$1"
  local name timestamp state
  case "$block" in
    "" | "(none)") p_info "(none)" ;;
    "(no resources)") p_info "$block" ;;
    "could not list"*) p_error "$block" ;;
    *)
      if [[ "$2" == "1" ]]; then
        # name, timestamp, state
        while IFS=$'\t' read -r name timestamp state; do
          [[ -z "$name" ]] && continue
          report_state "${state:-unknown}" "$name ($timestamp): ${state:-unknown}"
        done <<< "$block"
      else
        # name, state
        while IFS=$'\t' read -r name state; do
          [[ -z "$name" ]] && continue
          report_state "${state:-unknown}" "$name: ${state:-unknown}"
        done <<< "$block"
      fi
      ;;
  esac
}

# report_group <label> <rg-name>: prints one group's collected results.
report_group() {
  local label="$1"
  local rg_name="$2"
  local rg_state="${GROUP_RG_STATE[$label]:-unknown}"

  step "Resource group $rg_name ($label)"
  report_state "$rg_state" "provisioningState: $rg_state"

  p_step "Resources:"
  report_rows "${GROUP_RES_TEXT[$label]:-}" 0

  p_step "Latest deployments:"
  report_rows "${GROUP_DEP_TEXT[$label]:-}" 1
}

# report_sub_deployments <label> <rows> <ok>: prints the collected
# subscription-scope deployments for <label> ("environment" / "shared"). <ok> is
# 0 when the listing itself failed; empty <rows> just means nothing deployed yet.
report_sub_deployments() {
  local label="$1"
  local rows="$2"
  local ok="$3"

  step "Subscription deployments ($label)"
  if [[ "$ok" != "1" ]]; then
    p_error "could not list $label subscription deployments (see above)"
    return 0
  fi
  report_rows "$rows" 1
}

log_vars \
  "Subscription=$(subscription_name) ($SUBSCRIPTION_ID)" \
  "Resource group=$RG_NAME" \
  "Shared resource group=$SHARED_RG_NAME"

ENV_SUB_ROWS=""
ENV_SUB_OK=1
SHARED_SUB_ROWS=""
SHARED_SUB_OK=1

if [[ "$CHECK_ENV" == "1" ]]; then
  check_group "$RG_NAME" "environment"

  step "Fetching environment subscription deployments..."
  if ! fetch_sub_deployments "${BASE_NAME}-${ENVIRONMENT}-"; then
    ENV_SUB_OK=0
  else
    ENV_SUB_ROWS="$SUB_ROWS"
  fi
fi

if [[ "$CHECK_SHARED" == "1" ]]; then
  check_group "$SHARED_RG_NAME" "shared"

  step "Fetching shared subscription deployments..."
  if ! fetch_sub_deployments "${BASE_NAME}-shared-"; then
    SHARED_SUB_OK=0
  else
    SHARED_SUB_ROWS="$SUB_ROWS"
  fi
fi

# ---------------------------------------------------------------- report ----

success "Information collection completed."
echo ""
step "Report"
log_vars \
  "Subscription=$(subscription_name) ($SUBSCRIPTION_ID)" \
  "Scope=$([[ "$CHECK_ENV" == "1" && "$CHECK_SHARED" == "1" ]] && echo 'environment + shared' || ([[ "$CHECK_ENV" == "1" ]] && echo 'environment only' || echo 'shared only'))"

if [[ "$CHECK_ENV" == "1" ]]; then
  report_group "environment" "$RG_NAME"
fi

if [[ "$CHECK_SHARED" == "1" ]]; then
  report_group "shared" "$SHARED_RG_NAME"
fi

if [[ "$CHECK_ENV" == "1" ]]; then
  report_sub_deployments "environment" "$ENV_SUB_ROWS" "$ENV_SUB_OK"
fi

if [[ "$CHECK_SHARED" == "1" ]]; then
  report_sub_deployments "shared" "$SHARED_SUB_ROWS" "$SHARED_SUB_OK"
fi

step "Summary"
if [[ "$OVERALL" == "0" ]]; then
  success "Check complete: everything Succeeded."
else
  error "Check complete: something is not Succeeded (see above)."
fi
exit "$OVERALL"
