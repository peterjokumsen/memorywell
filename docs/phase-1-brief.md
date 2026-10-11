# Phase 1 Brief — Foundation

> Status: brief issued, not built. Human builds by hand. Agent unblocks only.

## 1. Goal

Provision the cheapest viable Azure foundation with Bicep and deploy a skeleton
FastAPI container to Container Apps with revision management on day one.

Deploys: resource group, Log Analytics, Key Vault, App Configuration, ACR,
Container Apps environment + skeleton API app. Plus `scripts/teardown.sh`.

Out of scope: Cosmos, Postgres, Redis, Service Bus, Event Grid, Functions,
agents (4a–4c), frontend, voice/photo, observability wiring. No pre-building
later phases.

## 2. AI-200 concepts practised

- Containerized solutions: Dockerfile → ACR (ACR Tasks build) → Container Apps
  (environment config, revisions, scale-to-zero).
- Connect/consume: Key Vault references + App Config values injected as env vars
  (managed identity where possible, even if only the API's identity is created
  now and wired later).
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
   - App Configuration (free tier, no keys yet — one placeholder e.g.
     `app:env = dev` is fine).
   - ACR (Basic SKU).
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
5. **`scripts/deploy.sh`.** Steps: `az group create` (if RG scope), `az deployment
   ... create` with parameters, `az acr build -r <registry> -t api:phase1 .`
   from `api/`, `az containerapp update --image <registry>/api:phase1`
   (creates revision 2 — this is the revision-management proof).
6. **`scripts/teardown.sh`.** Deletes the resource group
   (`az group delete --name <rg> --yes --no-wait` at minimum). Must work from a
   fresh shell with only RG name / baseName as input. Test it once (see §6).
7. **`.env` hygiene.** Local-only `.env` (already git-ignored) holds
   subscription ID, RG name, registry name. Nothing secret committed.
   Run `git status` — only intended files staged.

## 5. File outline (stubs, not implementations)

```plaintext
infra/main.bicep            # params (location, baseName, environment) + all Phase-1 resources
infra/main.bicepparam        # (optional) dev values; keep tiny
infra/modules/*.bicep       # (optional) one file per resource if you split step 3
api/main.py                 # FastAPI app, ~15 lines: two routes, nothing else
api/requirements.txt        # fastapi, uvicorn
api/Dockerfile              # FROM python:3.11-slim, COPY, EXPOSE 8000, CMD uvicorn
scripts/deploy.sh           # group create → bicep deploy → acr build → containerapp update
scripts/teardown.sh         # az group delete; echo what was removed
docs/phase-1-brief.md       # this file
```

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

- [ ] `az deployment ... create` (or group deployment) succeeds; portal shows
      RG with Log Analytics, Key Vault, App Config, ACR, Container Apps env + app.
- [ ] `curl https://<api-fqdn>/health` → `{"status":"ok"}`.
- [ ] After step 5's image update, `az containerapp revision list` shows ≥2
      revisions with the latest active.
- [ ] `scripts/teardown.sh` deletes the RG; redeploy from scratch works
      (proves no portal click-ops).
- [ ] `git status --short` shows no `.env`, no secrets, no `functions/`/`web/`.

## 7. Review gate (demo before Phase 2)

Paste back into chat:

1. `az containerapp show` FQDN + `curl /health` output.
2. `az containerapp revision list --output table` (≥2 revisions).
3. `scripts/deploy.sh` + `scripts/teardown.sh` run logs (success lines enough).
4. `git status --short` + `git log --oneline -5`.
5. One paragraph: subscription vs RG deployment choice, region choice, and what
   you'd do differently.

Agent sanity-checks the above, then issues the Phase 2 brief. No Phase 2 work
starts until the gate passes. Cost reminder: destroy resources between sessions
(`scripts/teardown.sh`); Phase 1 running cost should be ≈ ACR Basic + near-zero
consumption.
