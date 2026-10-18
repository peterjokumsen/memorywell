#!/usr/bin/env bash
# Run the Phase 2 seed (scripts/seed.py) with its output captured in logs/.
#
# This is the logging wrapper the seed's own docstring asks for: seed.py reads
# COSMOS_ENDPOINT / COSMOS_DATABASE / VAULT_NAME from the environment rather
# than deriving them, so it has to be run from a shell where scripts/common.sh
# has been sourced. Doing that by hand (`source common.sh && .venv/bin/python
# scripts/seed.py`) leaves nothing in logs/ — and when the seed fails halfway
# through Cosmos, Postgres and Redis, the traceback is the only thing that says
# which store broke. This script supplies the same environment, writes the
# three standard command logs, and exits with seed.py's status.
#
#   ./scripts/seed.sh                 run the seed
#   ./scripts/seed.sh <seed.py args>  extra arguments are forwarded to seed.py
#   PYTHON=/usr/bin/python3.11 ./scripts/seed.sh   use another interpreter
#
# Idempotent, so running it twice is safe — that is exactly how the Step 5
# verify check proves idempotency, and each run gets its own timestamped logs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# prepare environment variables
source "$SCRIPT_DIR/common.sh"

# Same env every invocation: the Python script must not derive these names
# itself or they drift from the shell/Bicep side (see seed.py's module
# docstring). Resolved against $ROOT below so the script can be invoked from any
# working directory.
SEED_SCRIPT="scripts/seed.py"
# The venv from step 5 by default; PYTHON overrides it, and the flag records
# which happened so the failure message can give the right fix.
PYTHON_OVERRIDDEN=0
if [[ -n "${PYTHON:-}" ]]; then
  PYTHON_OVERRIDDEN=1
else
  PYTHON="$ROOT/.venv/bin/python"
fi

init_command_log "seed"

# DefaultAzureCredential picks its subscription from the active `az` context, so
# the seed could otherwise write to whichever subscription the CLI happens to
# have selected. Same first line deploy.sh uses.
step "Setting subscription..."
run az account set --subscription "$SUBSCRIPTION_ID"

if [[ ! -x "$PYTHON" ]]; then
  error "Python interpreter not found or not executable: $PYTHON"
  if [[ "$PYTHON_OVERRIDDEN" -eq 0 ]]; then
    error "Create the venv and install the seed dependencies first:"
    error "  python -m venv .venv && .venv/bin/pip install -r scripts/seed-requirements.txt"
  else
    error "PYTHON is overridden by you — point it at an existing interpreter."
  fi
  exit 1
fi
if [[ ! -f "$ROOT/$SEED_SCRIPT" ]]; then
  error "Seed script not found: $ROOT/$SEED_SCRIPT"
  exit 1
fi

log_vars \
  "Environment=$ENVIRONMENT" \
  "Resource group=$RG_NAME" \
  "Cosmos account=$COSMOS_ACCOUNT_NAME" \
  "Key Vault=$VAULT_NAME" \
  "Interpreter=$PYTHON"

# The seed is one noisy section: every store it touches prints its own progress,
# and in CI the whole thing is more useful collapsed than interleaved with the
# header. run (not a bare invocation) is what routes the output into
# logs/seed-<stamp>_stdout.log and _stderr.log as it is produced, so a hung or
# crashed run is already readable from the log.
group "Seeding $RG_NAME"
step "Running $SEED_SCRIPT..."
if run "$PYTHON" "$ROOT/$SEED_SCRIPT" "$@"; then
  success "Seed completed."
else
  rc=$?
  endgroup
  error "Seed failed (exit $rc). Its output is in:"
  error "  $STDOUT_LOG"
  error "  $STDERR_LOG"
  exit "$rc"
fi
endgroup

# Log paths were printed by init_command_log above; the Step 5 verify check reads
# row counts off the stores themselves, so nothing further to report here.
success "Seed finished. Logs: $STDOUT_LOG | $STDERR_LOG"
