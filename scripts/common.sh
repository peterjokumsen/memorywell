ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -o allexport; source "$ROOT/.env"; set +o allexport
  echo "Loaded .env"
fi

: "${BASE_NAME:?set BASE_NAME in .env}"
: "${ENVIRONMENT:=dev}"
: "${LOCATION:?set LOCATION in .env}"
: "${SUBSCRIPTION_ID:?set SUBSCRIPTION_ID in .env}"

export RG_NAME="rg-${BASE_NAME}-${ENVIRONMENT}"
export DEPLOYMENT_NAME="${BASE_NAME}-${ENVIRONMENT}"

log_vars() {
  for kvp in "$@"; do
    printf '  %-16s %s' "${kvp%%=*}:" "${kvp#*=}"
      echo
  done
}
