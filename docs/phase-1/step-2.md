# Phase 1 · Step 2 — `infra/main.bicep`

**`infra/main.bicep` (subscription or RG scope — your choice, document it).**
Parameters: `location` (default `swedencentral` or nearest cheap region),
`baseName` (default `memwell`), `environment` (default `dev`).
Resources, cheapest SKUs:

- Log Analytics workspace (PerGB2018).
- Key Vault (standard SKU, RBAC authorization enabled, no secrets yet).
- ACR (Basic SKU). (App Configuration intentionally omitted — deferred for
  cost/value, see [\_brief.md](./_brief.md) §5.)
- Container Apps managed environment (wired to Log Analytics) + one
  Container App `api` (external ingress, target port 8000, minReplicas 0).

## Verify

- [x] `az deployment sub create` via `scripts/deploy.sh` succeeds (Bicep
      compiles clean: `az bicep build --file infra/main.bicep`); portal shows
      RG with Log Analytics, Key Vault, ACR, Container Apps env + app.
