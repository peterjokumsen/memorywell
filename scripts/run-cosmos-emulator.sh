#!/usr/bin/env bash
set -euo pipefail
NAME=cosmos-emulator
IMAGE=mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:latest
if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
  docker start "$NAME" >/dev/null
else
  docker run -d --name "$NAME" -p 8081:8081 -p 10251:10251 -p 10252:10252 -p 10253:10253 -p 10254:10254 "$IMAGE" >/dev/null
fi
echo "Cosmos emulator running. Set COSMOS_ENDPOINT=https://localhost:8081 COSMOS_KEY=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw== COSMOS_DATABASE=memorywell"
