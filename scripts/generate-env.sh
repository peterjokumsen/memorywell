#!/usr/bin/env bash
# Generate .env from .env.example, filling the values that cannot be committed:
# the subscription ID, the Postgres admin password, and the Cosmos data-plane
# principal. Everything else is copied from .env.example unless overridden.
#
# The lookup/generation commands match the hints in .env.example:
#   subscription   az account show --query id -o tsv
#   password       LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
#   principal      az ad signed-in-user show --query id -o tsv
#
# Never prints the generated password. Refuses to overwrite an existing .env
# unless --force is passed, in which case the old file is backed up first.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Only the logging helpers: common.sh requires .env to already exist.
source "$SCRIPT_DIR/_log.sh"

EXAMPLE="$ROOT/.env.example"
TARGET="$ROOT/.env"

FORCE=0
BASE_NAME=""
ENVIRONMENT=""
LOCATION=""

usage() {
  cat <<EOF
Usage: $0 [--base-name NAME] [--environment dev|test|prod] [--location REGION] [--force]
  --base-name NAME     Prefix for all Azure resource names (default: from .env.example)
  --environment ENV    dev, test or prod (default: from .env.example)
  --location REGION    Azure region, e.g. westeurope (default: from .env.example)
  --force              Replace an existing .env (a timestamped backup is kept)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-name)
      BASE_NAME="${2:-}"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    --location)
      LOCATION="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
  esac
done

# Read a value from the template. Used for the non-secret defaults so the
# example stays the single place that defines them.
example_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$EXAMPLE" | head -n 1
}

if [[ ! -f "$EXAMPLE" ]]; then
  error "Missing $EXAMPLE"
  exit 1
fi

for key in BASE_NAME ENVIRONMENT LOCATION SUBSCRIPTION_ID POSTGRES_ADMIN_PASSWORD COSMOS_USER_OBJECT_ID; do
  if ! grep -q "^${key}=" "$EXAMPLE"; then
    error "$EXAMPLE is missing ${key}=; update the template first."
    exit 1
  fi
done

if [[ -e "$TARGET" && "$FORCE" != "1" ]]; then
  error "$TARGET already exists. Re-run with --force to replace it."
  exit 1
fi

BASE_NAME="${BASE_NAME:-$(example_value BASE_NAME)}"
ENVIRONMENT="${ENVIRONMENT:-$(example_value ENVIRONMENT)}"
LOCATION="${LOCATION:-$(example_value LOCATION)}"

if [[ -z "$BASE_NAME" ]]; then
  error "--base-name is required (no default in .env.example)"
  exit 1
fi
if [[ ! "$BASE_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  error "Invalid --base-name '$BASE_NAME' (lowercase letters, digits and '-' only)"
  exit 1
fi
case "$ENVIRONMENT" in
  dev | test | prod) ;;
  *)
    error "Invalid --environment '$ENVIRONMENT' (expected dev, test or prod)"
    exit 1
    ;;
esac
if [[ -z "$LOCATION" ]]; then
  error "--location is required (no default in .env.example)"
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  error "az CLI not found. Install it and run 'az login' first."
  exit 1
fi

step "Resolving subscription..."
if ! SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null)" || [[ -z "$SUBSCRIPTION_ID" ]]; then
  error "Could not read the current subscription. Run 'az login' first."
  exit 1
fi
success "  Subscription: $SUBSCRIPTION_ID"

step "Generating Postgres admin password..."
# `head -c` closes the pipe early, so tr exits with SIGPIPE; tolerate it and
# keep the 32 bytes it already produced.
POSTGRES_ADMIN_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 || true)"
if [[ ${#POSTGRES_ADMIN_PASSWORD} -ne 32 ]]; then
  error "Password generation failed (expected 32 characters)."
  exit 1
fi
success "  Generated 32-character password (not shown)."

step "Resolving signed-in user for Cosmos data-plane access..."
# A service principal has no signed-in user; the grant is optional, so an
# empty value is valid and main.bicepparam treats it as "skip".
if COSMOS_USER_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv 2>/dev/null)" && [[ -n "$COSMOS_USER_OBJECT_ID" ]]; then
  success "  Cosmos principal: $COSMOS_USER_OBJECT_ID"
else
  COSMOS_USER_OBJECT_ID=""
  warn "  No signed-in user (service principal?); COSMOS_USER_OBJECT_ID left empty."
fi

step "Writing ${TARGET#"$ROOT"/}..."
if [[ -e "$TARGET" ]]; then
  backup="$TARGET.bak.$(date -u +%Y%m%d-%H%M%S)"
  cp -p "$TARGET" "$backup"
  chmod 600 "$backup"
  warn "  Backed up existing .env to ${backup#"$ROOT"/}"
fi

tmp="$(mktemp "$ROOT/.env.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    BASE_NAME=*) printf 'BASE_NAME=%s\n' "$BASE_NAME" ;;
    ENVIRONMENT=*) printf 'ENVIRONMENT=%s\n' "$ENVIRONMENT" ;;
    LOCATION=*) printf 'LOCATION=%s\n' "$LOCATION" ;;
    SUBSCRIPTION_ID=*) printf 'SUBSCRIPTION_ID=%s\n' "$SUBSCRIPTION_ID" ;;
    POSTGRES_ADMIN_PASSWORD=*) printf 'POSTGRES_ADMIN_PASSWORD=%s\n' "$POSTGRES_ADMIN_PASSWORD" ;;
    COSMOS_USER_OBJECT_ID=*) printf 'COSMOS_USER_OBJECT_ID=%s\n' "$COSMOS_USER_OBJECT_ID" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$EXAMPLE" > "$tmp"

# .env holds the Postgres password: keep it out of other users' reach and out
# of git (already covered by .gitignore).
chmod 600 "$tmp"
mv "$tmp" "$TARGET"
trap - EXIT

success "Created ${TARGET#"$ROOT"/} (mode 600)."
info "  BASE_NAME=$BASE_NAME"
info "  ENVIRONMENT=$ENVIRONMENT"
info "  LOCATION=$LOCATION"
info "  SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
info "  POSTGRES_ADMIN_PASSWORD=<generated>"
info "  COSMOS_USER_OBJECT_ID=${COSMOS_USER_OBJECT_ID:-<empty>}"
info "Next: ./scripts/provision-all.sh"
