# Phase 1 · Step 7 — `scripts/provision-shared.sh`

**`scripts/provision-shared.sh` (implemented).** One-time shared deployment:
`az deployment sub create` against `infra/shared.bicep` (create/what-if),
with the same `Deleting`-RG guard as `provision-env.sh`. Run before the first env
deploy.

## Verify

- [x] `./scripts/provision-shared.sh` creates `rg-<base>-shared` with the ACR;
      subsequent `./scripts/provision-env.sh` pulls from it (AcrPull via
      `infra/modules/acr-pull.bicep`) instead of failing on a missing
      registry.
