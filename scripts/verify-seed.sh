#!/usr/bin/env bash
# Run the Phase 2 seed verification (scripts/verify_seed.py) against the live
# environment. Read-only — it checks the seed, it cannot break it.
#
#   ./scripts/verify-seed.sh     verify; exit 0 all passed, 1 a check failed
#
# This is the executable form of the Verify checklist in
# docs/phase-2/step-5.md. It cannot run in CI: it needs live Azure resources,
# which are not free, so the phase briefs keep such checks manual and this
# script exists to make them repeatable rather than to gate a PR.
#
# Why a wrapper instead of running the Python directly: verify_seed.py needs
# COSMOS_ENDPOINT, COSMOS_DATABASE and VAULT_NAME, which common.sh derives from
# .env. That is the same contract seed.py has, and sourcing here is what makes
# it hold — a `source scripts/common.sh && python ...` incantation is one typo
# away from an env var that silently reads as empty.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
Usage: $0

Verifies the Phase 2 seed against the live stores (Cosmos, Redis, Postgres)
and checks the docs/phase-2/step-5.md Verify list. Read-only.

Exit codes:
  0  every check passed
  1  at least one check failed
 64 usage error
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 0 ]]; then
  printf 'Unknown argument: %s\n' "$1" >&2
  usage >&2
  exit 64
fi

# prepare environment variables
# shellcheck source=scripts/common.sh
source "${ROOT}/scripts/common.sh"

# The seed's pinned dependencies live in the repo venv, not in a system Python:
# verify_seed.py imports seed.py, which imports the same three SDKs. A different
# interpreter could have none of them, or the wrong versions.
PYTHON="${ROOT}/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  error "No venv at ${ROOT}/.venv. Create it and install the seed dependencies:"
  error "  python -m venv .venv && .venv/bin/pip install -r scripts/seed-requirements.txt"
  exit 1
fi

step "Verifying the Phase 2 seed..."
"$PYTHON" "${ROOT}/scripts/verify_seed.py"
