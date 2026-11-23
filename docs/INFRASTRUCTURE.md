# Infrastructure & Provisioning

Consolidated from Phase 1 (Foundation).

## Overview

- Bicep subscription deployment provisions cheapest viable Azure foundation.
- `scripts/provision-env.sh`: `az deployment sub create`, ACR build with floating + timestamp tags, containerapp update to timestamp tag, `/health` retry.
- `scripts/teardown.sh`: deletes RG; `--purge-vault` waits/purges soft-deleted Key Vault.
- `scripts/provision-shared.sh`: one-time shared deployment (ACR in shared RG) with `AcrPull` grant.
- `.env` (git-ignored) holds subscription/RG/registry names.

## Modules

- `infra/main.bicep` (params: location, baseName, environment)
- Optional modules: ACR, Key Vault, App Config, Monitor, Container App.

## Skeleton API

- `api/` FastAPI with `/health`, `/ready`; Dockerfile exposes 8000.
  "
