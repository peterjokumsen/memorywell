# Phase 1 · Step 6 — `scripts/teardown.sh`

**`scripts/teardown.sh` (implemented).** Deletes the resource group
(`az group delete --name <rg> --yes --no-wait`); pass `--purge-vault` to
also wait for (up to ~5 min) and purge the soft-deleted Key Vault
(`kv-<base>-<env>`) so same-name redeploys do not conflict. Pass `--shared`
to also delete the shared RG (`rg-<base>-shared`), always after the env RG
so running apps never lose image pulls mid-teardown; without the flag the
shared RG and its images are kept across sessions. Must work from
a fresh shell with only `.env` values. Uses the `DEPLOYMENT_NAME` naming
from [step-5.md](./step-5.md) (`scripts/common.sh`).

## Verify

- [x] `scripts/teardown.sh --purge-vault` deletes the RG and purges the
      soft-deleted Key Vault (evidenced 2026-10-11: 1 soft-delete wait
      retry, `Teardown complete (resource group deleted, vault purged)`).
- [x] Redeploy from scratch works (proves no portal click-ops) — reported
      2026-10-11: 2× fresh deploys from absent RG after teardown.
