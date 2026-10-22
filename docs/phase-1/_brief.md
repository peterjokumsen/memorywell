# Phase 1 Brief — Foundation

> Status: complete pending commit (2026-10-11). Bicep subscription deployment,
> `az acr build` (floating env tag + unique timestamp tag) + `containerapp
update` to timestamp tag + `/health` retry check all implemented in
> `scripts/provision-env.sh` and run live; FQDN + `/health` ok, ≥2 revisions,
> `teardown.sh --purge-vault` evidenced in chat; 2× scratch redeploys from
> absent RG reported. Left: remove `deploy-log`, commit, `git status`
> self-check. Human builds by hand. Agent unblocks only.
>
> Update (2026-10-12): ACR moved to a shared resource group
> (`infra/shared.bicep`, `scripts/provision-shared.sh`); env template references
> it as `existing` and grants `AcrPull` via `infra/modules/acr-pull.bicep`.
>
> Layout: one `step-x.md` per ordered step in this directory; each step file
> carries its own instructions, stub shapes/notes, and verification checks.

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

One step per file, in order:

| Step | File                   | What you build                                                        |
| ---- | ---------------------- | --------------------------------------------------------------------- |
| 1    | [step-1.md](step-1.md) | Scaffold the empty layout (`infra/`, `api/`, `scripts/`)              |
| 2    | [step-2.md](step-2.md) | `infra/main.bicep` (+ `main.bicepparam`) — cheapest-viable foundation |
| 3    | [step-3.md](step-3.md) | Split Bicep modules only if it helps you learn                        |
| 4    | [step-4.md](step-4.md) | Skeleton API (stub only)                                              |
| 5    | [step-5.md](step-5.md) | `scripts/provision-env.sh` (implemented)                              |
| 6    | [step-6.md](step-6.md) | `scripts/teardown.sh` (implemented)                                   |
| 7    | [step-7.md](step-7.md) | `scripts/provision-shared.sh` (implemented)                           |
| 8    | [step-8.md](step-8.md) | `.env` hygiene                                                        |

Do not start a step before the previous one verifies. No Phase 2 work starts
until the §6 review gate passes.

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
scripts/provision-shared.sh   # sub deploy of infra/shared.bicep (shared RG + ACR) ✅; fails fast on shared RG still Deleting ✅
scripts/provision-env.sh           # sub deploy ✅; requires shared RG/ACR (points at provision-shared.sh when missing) ✅; IMAGE fallback ✅; acr build (env + timestamp tags) + containerapp update to timestamp tag ✅; /health retry ✅
scripts/common.sh           # .env loader + RG_NAME/SHARED_RG_NAME/SHARED_ACR_NAME + registry_name()/login_server() helpers/log_vars shared by scripts; timestamped DEPLOYMENT_NAME (see step-5) + derived IMAGE_TAG (<env>-YYYYmmdd-HHMMSS, unique per run so each update mints a new revision); color helpers step/info/success/warn/error (TTY-only, NO_COLOR-aware)
scripts/teardown.sh         # az group delete + Key Vault purge ✅; `--shared` also deletes the shared RG (env RG first) ✅
.env.example                # BASE_NAME/ENVIRONMENT/LOCATION/SUBSCRIPTION_ID template (no secrets)
docs/phase-1/               # this brief (_brief.md) + one step-x.md per step
```

Dropped from Phase 1 scope (deferred for cost/value, not deleted from PLAN):
App Configuration — no key-values are consumed in Phase 1, so provisioning it
adds cost/complexity with no learning payoff. The stub
(`infra/modules/appconfig.bicep`) stays removed; it returns with persona /
threshold / feature-flag keys in Phases 4a–4c. `scripts/prepare.sh` outline
removed — superseded by `provision-env.sh` + `common.sh`. `infra/main.json` is local
`az bicep build` output, never committed.

## 6. Review gate (demo before Phase 2)

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
   provision-env.sh into their specific steps to allow for containerapp deployment
   without having to re-deploy biceps.

Agent sanity-checks the above, then issues the Phase 2 brief. No Phase 2 work
starts until the gate passes. Cost reminder: destroy resources between sessions
(`scripts/teardown.sh`); Phase 1 running cost should be ≈ ACR Basic + near-zero
consumption.
