# Phase 1 · Step 5 — `scripts/deploy.sh`

**`scripts/deploy.sh` (implemented).** `az deployment sub create` with
parameters, `IMAGE` exported for `main.bicepparam` (falls back to
Container Apps helloworld image when the ACR/repo does not exist yet —
expected on first deploy), `az acr build -r <registry> -t api:<env> -t
api:<env>-<timestamp> ./api` (floating env tag + unique timestamp tag
derived from `DEPLOYMENT_NAME` in `scripts/common.sh`), `az containerapp
update --image <registry>/api:<env>-<timestamp>` (unique tag string
guarantees a new revision on every run — this is the
revision-management proof), then `/health` poll
(`curl --max-time 5`, retry every 5s, up to ~60s for ACR pull +
scale-from-zero). Refuses to deploy while the RG is still in `Deleting`
state (async teardown drain — retry once `az group show` no longer
returns the group).

Deployment naming (`scripts/common.sh`): every `deploy.sh`/`teardown.sh` run
mints `DEPLOYMENT_NAME=<base>-<env>-YYYYmmdd-HHMMSS` (recorded in
`$TMPDIR/memorywell-<base>-<env>.deployment`) because subscription-deployment
names must be unique per `az deployment sub create` — re-using a name
overwrites history and confuses `sub show` lookups. Set
`REUSE_DEPLOYMENT=1` to re-run against the previous name when debugging a
failed deployment.

Notes (no open code TODOs):

- Pre-deploy ACR tag check explicitly tolerates a missing registry/repo
  (first deploy → helloworld fallback, then real image via `acr build`).
- `main.bicepparam` reads `IMAGE` from env — `deploy.sh` exports it, so the
  fallback vs real-image choice actually reaches Bicep.

## Verify

- [x] Code path done and run live: `az acr build` (env + timestamp tags) +
      `az containerapp update` to timestamp tag; `/health` retry loop
      (`--max-time 5`, 5s sleep, 12 attempts) returned `{"status":"ok"}`
      after 3 attempts at
      `https://ca-memwell-dev.agreeableforest-d1c26f62.westeurope.azurecontainerapps.io/health`
      (deployment `memwell-dev-20261011-194228`).
- [x] `az containerapp revision list` shows 2 revisions with latest active
      (evidenced 2026-10-11: `ca-memwell-dev--0000001` weight 0 +
      `ca-memwell-dev--0000002` weight 100, both Healthy). Timestamp tag
      (`api:<env>-<timestamp>`, `IMAGE_TAG` in `scripts/common.sh`) fixes
      the same-tag no-new-revision behaviour.
