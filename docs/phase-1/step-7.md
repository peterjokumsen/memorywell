# Phase 1 · Step 7 — `scripts/deploy-shared.sh`

**`scripts/deploy-shared.sh` (implemented).** One-time shared deployment:
`az deployment sub create` against `infra/shared.bicep` (create/what-if),
with the same `Deleting`-RG guard as `deploy.sh`. Run before the first env
deploy.

## Verify

- [x] `./scripts/deploy-shared.sh` creates `rg-<base>-shared` with the ACR;
      subsequent `./scripts/deploy.sh` pulls from it (AcrPull via
      `infra/modules/acr-pull.bicep`) instead of failing on a missing
      registry.
