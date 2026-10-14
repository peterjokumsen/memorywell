# Phase 2 · Step 2 — Group B: PostgreSQL + pgvector

**Group B — PostgreSQL (`infra/modules/postgres.bicep`, new).** Flexible
Server, Burstable `B1ms`, smallest storage, one database (`memorywell`),
`vector` extension enabled via server extension allowlist +
`CREATE EXTENSION`. Stub schema only: a `documents` table (`id uuid pk`,
`chronicleId text`, `contributorId text`, `topic text`,
`createdAt timestamptz`, `embedding vector(1536)`, `metadata jsonb`)
created by the seed script, not Bicep. Note the pooling story (Flexible
Server built-in pooler) in a comment. Nothing else in this step — no
Cosmos, no Redis.

`vector(1536)` must match the vector dimension you recorded in
[step-1.md](./step-1.md).

## Progress snapshot (2026-10-14)

Status: **deployed and verified (2026-10-14).** Live as `pg-memwell-dev` in
`rg-memwell-dev`; reachable, `azure.extensions` allowlists `vector`, and
`memorywell` exists. The `documents` table is still expected to be absent —
step 5's seed owns schema creation.

### What is in place

- `infra/modules/postgres.bicep` (new): Flexible Server `pg-<base>-<env>`,
  `Standard_B1ms`/Burstable, `version: '16'`, 32 GiB storage,
  `highAvailability.mode: 'Disabled'`, 7-day backup,
  `publicNetworkAccess: 'Enabled'`; child resources for the `memorywell`
  database, the `azure.extensions = 'vector'` allowlist, and an
  `allow-client` firewall rule built from the client IP.
- Param threading: `@secure()` `postgresAdministratorPassword` +
  `postgresClientIp` declared on `main.bicep`, forwarded through
  `platform.bicep` into the module; both sourced in `main.bicepparam` via
  `readEnvironmentVariable` (so no `deploy.sh` change was needed);
  `POSTGRES_ADMIN_PASSWORD` added to `.env`/`.env.example`.
- Dims decision closed at `1536` on both sides (Cosmos `memories.embedding`
  vector index, `documents.embedding vector(1536)`), recorded in
  [step-1.md](./step-1.md).

### API-version property names (verified against the Bicep types)

Bicep reports an unknown property as a _warning_ and still emits a template,
so these fail at ARM time rather than build time:

| Natural guess           | Actual property              |
| ----------------------- | ---------------------------- |
| `administratorPassword` | `administratorLoginPassword` |
| `storage.autoGrowth`    | `storage.autoGrow`           |
| `backup.retentionDays`  | `backup.backupRetentionDays` |

`authConfig` (for Entra-only admin, still open) uses
`activeDirectoryAuth`, not `entraAuth`.

### Resolved during the deploy

1. **`CLIENT_ID` vs `CLIENT_IP` mismatch — closed.** The blocker was that
   `scripts/common.sh` exported the ipify result as `CLIENT_ID` while
   `main.bicepparam` read `CLIENT_IP`, so the firewall rule got an empty
   string. Fixed by renaming the export to `CLIENT_IP`, which is also the
   honest name for it — `CLIENT_ID` is the usual variable for an Entra
   service principal's client id and should not be carrying a home IP.
2. **`adminstratorLogin` typo — fixed** (`administratorLogin` in both
   `postgres.bicep` and the `platform.bicep` call site).
3. **SKU name — fixed to `Standard_B1ms`.** The short `B1ms` is what the
   docs/portal show, but the ARM API wants the full name.
4. **Pooling comment — written**, on the `server` resource in `postgres.bicep`.
5. **Cost guards to keep:** `highAvailability.mode: 'Disabled'` (the ARM
   default is ZoneRedundant — 2× cost, needs zones) and
   `storage.autoGrow: 'Disabled'` (a runaway vector table would otherwise
   resize the server silently). Both confirmed live.

### Verify

- [x] `./scripts/deploy.sh what-if` shows the Flexible Server, database,
      `azure.extensions` and firewall rule. Live state matches the template:
      both child resources report **no change**, and the server-level diffs
      are ARM echoing defaults back (`authConfig.activeDirectoryAuth
"Disabled"`, `dataEncryption.type "SystemManaged"`,
      `storage.iops 120` / `tier P4` / `type Premium_LRS`) — no-ops.
- [x] `./scripts/deploy.sh create` succeeds.
- [x] `az postgres flexible-server show -g rg-memwell-dev -n pg-memwell-dev`
      → `Standard_B1ms` / `Burstable`, `highAvailability.mode "Disabled"`,
      `state: Ready`, `publicNetworkAccess "Enabled"`, `version 16` (minor 15),
      FQDN `pg-memwell-dev.postgres.database.azure.com`.
- [x] Firewall rule `allow-client` = `45.222.74.0`/`45.222.74.0`, matching
      `curl https://api.ipify.org` at deploy time. A successful `psycopg`
      connection from this machine confirms it end to end.
- [x] `SHOW azure.extensions` returns `vector` (via
      `az postgres flexible-server parameter show --name azure.extensions`,
      `source: user-override`).
- [ ] `SELECT * FROM pg_extension WHERE extname='vector'` returns a row — but
      only _after_ step 5 runs `CREATE EXTENSION`. Bicep only allowlists the
      extension; it never installs it. Currently empty, as expected. Before
      the seed, check the allowlist instead: `SHOW azure.extensions` should
      list `vector`.
- [ ] `documents` table exists after the seed runs
      ([step-5.md](./step-5.md)). `pg_tables WHERE schemaname='public'` is
      currently empty.

### Notes

- No local `psql`. Verify through the venv: `uv pip install "psycopg[binary]"`
  (step 5 needs it anyway) rather than a throwaway Docker image.
- The compiled `main.bicepparam` JSON embeds the password in plain text. It is
  az's local temp artifact, never committed (`infra/**/*.json` is gitignored),
  and the deployment history records the param as secure — but it does sit on
  disk in `/tmp` during deploys.
- Q1 (password vs Entra-only admin) was built as the `@secure()` password
  path. Q2 (public + firewall rule vs private/VNet) was built as public +
  firewall. Both were unconfirmed; switching to Entra-only later means adding
  `flexibleServers/administrators` + `authConfig.activeDirectoryAuth`, and a
  token exchange in the seed script.
- `POSTGRES_ADMIN_PASSWORD` is now locked in. It is a create-only property:
  changing it in `.env` and redeploying fails on an existing server. Rotate
  with `az postgres flexible-server admin update`, not a redeploy.
- Live `max_connections` is `50` (B1ms, 2 vCPU). Phase 3 must budget it across
  the three agents, and the Flexible Server pooler wants its own
  `pooler.postgres.database.azure.com` FQDN — noted in the `postgres.bicep`
  comment.
- `az postgres flexible-server config` no longer exists in azure-cli 2.91; the
  command is `az postgres flexible-server parameter`.
- what-if reports `properties.charset: "UTF8" => "utf8"` on the database. Pure
  casing noise — ARM echoes the value back uppercase — but it means that line
  will never reach "no change".
- Pre-existing from Phase 1, unrelated to this step: what-if flags
  `enableAutomaticFailover: true => false` on the Cosmos account and 9 Cosmos
  containers as "to modify". Those are ARM defaults being re-stated, but worth
  a look before the Phase 2 review gate.
