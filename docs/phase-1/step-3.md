# Phase 1 · Step 3 — Split modules only if it helps you learn

**Split modules only if it helps you learn** (e.g. `infra/modules/acr.bicep`,
`.../vault.bicep`, `.../appconfig.bicep`, `.../monitor.bicep`,
`.../containerapp.bicep`). Single `main.bicep` is acceptable for Phase 1 —
do not build all 11 PLAN modules now.

## Verify

- [x] Whatever split you chose still compiles clean
      (`az bicep build --file infra/main.bicep`) and deploys via
      `scripts/provision-env.sh` (step 5).
