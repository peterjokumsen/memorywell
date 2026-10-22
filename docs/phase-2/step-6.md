# Phase 2 · Step 6 — Deploy + hygiene

**Deploy + hygiene.** `az bicep build --file infra/main.bicep`,
`./scripts/provision-env.sh` (extends Bicep composition only — do not add a
container revision path here), verify per this step's checks below,
`scripts/teardown.sh` still destroys everything. `.env` stays ignored; seed
reads secrets from env, never hardcodes.

## Verify

- [x] `scripts/teardown.sh --purge-vault` still destroys everything (Phase 1
      stack + Phase 2 data stores).
- [x] `git status --short` shows no `.env`, no secrets.
