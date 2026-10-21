#!/usr/bin/env bash
# Build and push the event logger function image to ACR
# Usage: ./scripts/build-function-logger.sh <acr-name> [tag]

set -euo pipefail

ACR_NAME="${1:-}"
TAG="${2:-latest}"

if [[ -z "$ACR_NAME" ]]; then
  echo "Usage: $0 <acr-name> [tag]"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_DIR="${REPO_ROOT}/functions"
IMAGE_NAME="${ACR_NAME}.azurecr.io/memorywell-functions:${TAG}"

echo "Building function image: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" "${FUNCTIONS_DIR}"

echo "Logging into ACR..."
az acr login --name "${ACR_NAME}"

echo "Pushing image..."
docker push "${IMAGE_NAME}"

echo "Done. Image: ${IMAGE_NAME}"
