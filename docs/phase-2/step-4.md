# Phase 2 · Step 4 — Group D: Secrets + identity wiring

**Group D — Secrets and identity wiring (edit `infra/modules/platform.bicep`,
`infra/modules/vault.bicep`, and `infra/modules/cosmos.bicep` only).** The
Cosmos account is **keyless**: the deployed API authenticates with its
user-assigned identity, so there is no Cosmos connection string and nothing in
Key Vault for Cosmos. Postgres and Redis still use connection strings.

## 1. Cosmos — keyless, no secret

Do this in `cosmos.bicep` (account property) and `platform.bicep`
(composition):

- Set `disableLocalAuth: true` on the account. This is what actually enforces
  keyless — without it the account key still works and nothing else forces
  clients to use identity.
- Assign the API's user-assigned identity the Cosmos **Built-in Data
  Contributor** data-plane role (`00000000-0000-0000-0000-000000000001`) at
  **database** scope (`cosmos.bicep`, `scope: database`) rather than account
  scope, so a future second database is not implicitly readable.
- Pass the endpoint to the Container App as a **plain env var**
  (`COSMOS_ENDPOINT` from `cosmos.outputs.accountEndpoint`) plus
  `COSMOS_DATABASE` (from `cosmos.outputs.databaseName`). Not secrets —
  env vars are fine for non-sensitive values.
- Do **not** grant `Key Vault Secrets User` anything Cosmos-related and do not
  write a Cosmos secret. Nothing to rotate.

Note for step-5: with `disableLocalAuth: true` the seed script cannot use a
connection string either. Use `azure-cosmos` with `DefaultAzureCredential` (az
CLI login) and grant your own user object id the same data-plane role for
local dev, or seed the containers through Bicep/`az` instead.

## 2. Postgres and Redis — still secrets

Two secrets in the existing Key Vault: Postgres connection string, Redis
connection string. Grant the existing API user-assigned identity `Key Vault
Secrets User` (reuse the `secretsUser` pattern already in `vault.bicep`) — no
new identity. Wire both into `containerapp.bicep` via Key Vault references, not
literal values. Bicep must not emit secrets in outputs.

## Verify

- [ ] Cosmos account shows local-key auth **disabled**, and the API identity
      shows data contributor at database scope via
      `az cosmosdb sql role assignment list`.
- [ ] Key Vault holds exactly **two** secrets (Postgres, Redis); Bicep outputs
      contain no secret values; API identity holds `Key Vault Secrets User`.
- [ ] Container App env shows `COSMOS_ENDPOINT` / `COSMOS_DATABASE` as plain
      values and both Postgres/Redis vars as Key Vault references.
