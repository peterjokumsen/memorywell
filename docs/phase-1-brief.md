# Phase 1 Brief — Foundation

> Status: complete pending commit (2026-10-11). Bicep subscription deployment,
> `az acr build` (floating env tag + unique timestamp tag) + `containerapp
update` to timestamp tag + `/health` retry check all implemented in
> `scripts/deploy.sh` and run live; FQDN + `/health` ok, ≥2 revisions,
> `teardown.sh --purge-vault` evidenced in chat; 2× scratch redeploys from
> absent RG reported. Left: remove `deploy-log`, commit, `git status`
> self-check. Human builds by hand. Agent unblocks only.
>
> Update (2026-10-12): ACR moved to a shared resource group
> (`infra/shared.bicep`, `scripts/deploy-shared.sh`); env template references
> it as `existing` and grants `AcrPull` via `infra/modules/acr-pull.bicep`.

## 1. Goal

Provision the cheapest viable Azure foundation with Bicep and deploy a skeleton
FastAPI container to Container Apps with revision management on day one.

Deploys: resource group, Log Analytics, Key Vault, ACR,
Container Apps environment + skeleton API app. Plus `scripts/teardown.sh`.

App Configuration is deferred (see §5): no key-value load in Phase 1, so it
adds cost/complexity without learning value yet. It returns when persona
definitions / thresholds / feature flags land (Phases 4a–4c).

Out of scope: Cosmos, Postgres, Redis, Service Bus, Event Grid, Functions,
agents (4a–4c), frontend, voice/photo, observability wiring. No pre-building
later phases.

## 2. AI-200 concepts practised

- Containerized solutions: Dockerfile → ACR (ACR Tasks build) → Container Apps
  (environment config, revisions, scale-to-zero).
- Connect/consume: Key Vault references injected as env vars
  (managed identity where possible, even if only the API's identity is created
  now and wired later). App Config injection is deferred with the resource
  (see §5).
- Secure/monitor: Log Analytics attached to the Container Apps environment from
  day one; no secrets in repo.

## 3. Prerequisites

- Azure subscription ready (`az login` works, one subscription selected).
- Tools: Azure CLI + Bicep (`az bicep version`), Docker, Python 3.11+.
- This branch: `phase-1-foundation`, clean `git status`.
- Read: `docs/PLAN.md` §§ Decisions, Architecture §1 + §4, Build phases row 1.

## 4. Ordered steps (human builds)

1. **Scaffold empty layout.** Create dirs `infra/`, `infra/modules/`, `api/`,
   `scripts/` only. No `functions/`, `web/` yet.
2. **`infra/main.bicep` (subscription or RG scope — your choice, document it).**
   Parameters: `location` (default `swedencentral` or nearest cheap region),
   `baseName` (default `memwell`), `environment` (default `dev`).
   Resources, cheapest SKUs:
   - Log Analytics workspace (PerGB2018).
   - Key Vault (standard SKU, RBAC authorization enabled, no secrets yet).
   - ACR (Basic SKU). (App Configuration intentionally omitted — deferred for
     cost/value, see §5.)
   - Container Apps managed environment (wired to Log Analytics) + one
     Container App `api` (external ingress, target port 8000, minReplicas 0).
3. **Split modules only if it helps you learn** (e.g. `infra/modules/acr.bicep`,
   `.../vault.bicep`, `.../appconfig.bicep`, `.../monitor.bicep`,
   `.../containerapp.bicep`). Single `main.bicep` is acceptable for Phase 1 —
   do not build all 11 PLAN modules now.
4. **Skeleton API (stub only).** `api/main.py` with `/health` and `/ready`
   returning `{"status":"ok"}`; `api/requirements.txt` (fastapi + uvicorn);
   `api/Dockerfile` (slim python, expose 8000, run uvicorn). No agent code,
   no DB clients.
5. **`scripts/deploy.sh` (implemented).** `az deployment sub create` with
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
6. **`scripts/teardown.sh` (implemented).** Deletes the resource group
   (`az group delete --name <rg> --yes --no-wait`); pass `--purge-vault` to
   also wait for (up to ~5 min) and purge the soft-deleted Key Vault
   (`kv-<base>-<env>`) so same-name redeploys do not conflict. Pass `--shared`
   to also delete the shared RG (`rg-<base>-shared`), always after the env RG
   so running apps never lose image pulls mid-teardown; without the flag the
   shared RG and its images are kept across sessions. Must work from
   a fresh shell with only `.env` values. Test it once (see §6).
7. **`scripts/deploy-shared.sh` (implemented).** One-time shared deployment:
   `az deployment sub create` against `infra/shared.bicep` (create/what-if),
   with the same `Deleting`-RG guard as `deploy.sh`. Run before the first env
   deploy.
8. **`.env` hygiene.** Local-only `.env` (already git-ignored) holds
   subscription ID, RG name, registry name. Nothing secret committed.
   Run `git status` — only intended files staged.

## 5. File outline (stubs, not implementations)

```plaintext
infra/shared.bicep          # sub scope: shared RG (rg-<base>-shared) + ACR module, outputs registry/loginServer ✅
infra/shared.bicepparam     # shared values from env (BASE_NAME, LOCATION, SHARED_RG_NAME) ✅
infra/main.bicep            # subscription scope: RG + platform module, existing ACR ref + acr-pull module, outputs ✅
infra/main.bicepparam        # dev values from env (BASE_NAME, ENVIRONMENT, LOCATION, RG_NAME, IMAGE, SHARED_RG_NAME, SHARED_ACR_NAME)
infra/_types.bicep           # GlobalInputs, EnvironmentType
infra/modules/platform.bicep # RG-scope composition: identity, monitor, vault, containerapp (takes acrLoginServer) ✅
infra/modules/identity.bicep # user-assigned identity for the API app
infra/modules/monitor.bicep  # Log Analytics (PerGB2018)
infra/modules/acr.bicep      # ACR Basic, deployed by shared.bicep (no role grants here) ✅
infra/modules/acr-pull.bicep # AcrPull role for an env identity, deployed at the shared RG scope ✅
infra/modules/vault.bicep    # Key Vault standard, RBAC, Secrets User role
infra/modules/containerapp.bicep # env (Log Analytics wired) + api app, port 8000, minReplicas 0
api/main.py                 # FastAPI app, ~15 lines: two routes, nothing else ✅
api/requirements.txt        # fastapi, uvicorn (+ httpx/pytest for TestClient self-test) ✅
api/Dockerfile              # FROM python:3.11-slim, COPY, EXPOSE 8000, CMD uvicorn ✅ (+ non-root user)
api/tests/test_main.py      # /health + /ready assertions ✅
scripts/deploy-shared.sh   # sub deploy of infra/shared.bicep (shared RG + ACR) ✅; fails fast on shared RG still Deleting ✅
scripts/deploy.sh           # sub deploy ✅; requires shared RG/ACR (points at deploy-shared.sh when missing) ✅; IMAGE fallback ✅; acr build (env + timestamp tags) + containerapp update to timestamp tag ✅; /health retry ✅
scripts/common.sh           # .env loader + RG_NAME/SHARED_RG_NAME/SHARED_ACR_NAME + registry_name()/login_server() helpers/log_vars shared by scripts; timestamped DEPLOYMENT_NAME (see below) + derived IMAGE_TAG (<env>-YYYYmmdd-HHMMSS, unique per run so each update mints a new revision); color helpers step/info/success/warn/error (TTY-only, NO_COLOR-aware)
scripts/teardown.sh         # az group delete + Key Vault purge ✅; `--shared` also deletes the shared RG (env RG first) ✅
.env.example                # BASE_NAME/ENVIRONMENT/LOCATION/SUBSCRIPTION_ID template (no secrets)
docs/phase-1-brief.md       # this file
```

Deployment naming (`scripts/common.sh`): every `deploy.sh`/`teardown.sh` run
mints `DEPLOYMENT_NAME=<base>-<env>-YYYYmmdd-HHMMSS` (recorded in
`$TMPDIR/memorywell-<base>-<env>.deployment`) because subscription-deployment
names must be unique per `az deployment sub create` — re-using a name
overwrites history and confuses `sub show` lookups. Set
`REUSE_DEPLOYMENT=1` to re-run against the previous name when debugging a
failed deployment.

`.python-version` (content `3.11`) is a local `uv`/pyenv toolchain hint,
auto-generated and git-ignored — the build pins `python:3.11-slim` in
`api/Dockerfile` instead.

Dropped from Phase 1 scope (deferred for cost/value, not deleted from PLAN):
App Configuration — no key-values are consumed in Phase 1, so provisioning it
adds cost/complexity with no learning payoff. The stub
(`infra/modules/appconfig.bicep`) stays removed; it returns with persona /
threshold / feature-flag keys in Phases 4a–4c. `scripts/prepare.sh` outline
removed — superseded by `deploy.sh` + `common.sh`. `infra/main.json` is local
`az bicep build` output, never committed.

Stub shapes (write them yourself, keep them this small):

```python
# api/main.py — stub
from fastapi import FastAPI
app = FastAPI()

@app.get("/health")
def health(): return {"status": "ok"}

@app.get("/ready")
def ready(): return {"status": "ok"}
```

```dockerfile
# api/Dockerfile — stub
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py ./
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 6. Manual verification checks

- [x] `az deployment sub create` via `scripts/deploy.sh` succeeds (Bicep
      compiles clean: `az bicep build --file infra/main.bicep`); portal shows
      RG with Log Analytics, Key Vault, ACR, Container Apps env + app.
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
- [x] `scripts/teardown.sh --purge-vault` deletes the RG and purges the
      soft-deleted Key Vault (evidenced 2026-10-11: 1 soft-delete wait
      retry, `Teardown complete (resource group deleted, vault purged)`).
- [x] Redeploy from scratch works (proves no portal click-ops) — reported
      2026-10-11: 2× fresh deploys from absent RG after teardown.
- [x] `git status --short` shows no `.env`, no secrets, no `functions/`/`web/`
      (`.python-version` now git-ignored as local toolchain hint).
      `git log` paste waived — owner confirms log output is just commit
      history. Self-check before commit: `git status --short` lists only
      intended files. Still to do: remove untracked `deploy-log` at repo
      root (verbose deploy output, do not commit).

Notes (no open code TODOs):

- Pre-deploy ACR tag check explicitly tolerates a missing registry/repo
  (first deploy → helloworld fallback, then real image via `acr build`).
- `main.bicepparam` reads `IMAGE` from env — `deploy.sh` exports it, so the
  fallback vs real-image choice actually reaches Bicep.

## 7. Review gate (demo before Phase 2)

Paste back into chat:

1. ✅ Received: `az containerapp show` FQDN + `curl /health` output
   (`ca-memwell-dev.agreeableforest-d1c26f62.westeurope.azurecontainerapps.io`
   → `{"status":"ok"}`).
2. ✅ Received: `az containerapp revision list --output table` (2 revisions,
   latest active at weight 100).
3. ✅ Received: `scripts/teardown.sh --purge-vault` run log. Scratch-redeploy
   reported (2× fresh deploys from absent RG) — logs not pasted, accepted
   on report.
4. ✅ Waived/accepted: `git log` paste not needed (commit history only).
   Self-check before commit: `git status --short` shows only intended
   files, no `.env`/secrets (`rm deploy-log`, do not commit it).
5. ✅ Received (one paragraph): subscription preferred to be in charge of RG
   from scratch, and westeurope so far has no issues. Would strip out
   deploy.sh into their specific steps to allow for containerapp deployment
   without having to re-deploy biceps.

Agent sanity-checks the above, then issues the Phase 2 brief. No Phase 2 work
starts until the gate passes. Cost reminder: destroy resources between sessions
(`scripts/teardown.sh`); Phase 1 running cost should be ≈ ACR Basic + near-zero
consumption.
