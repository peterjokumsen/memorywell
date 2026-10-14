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

Status: **implemented by hand, not yet deployed, not yet verified.** Committed
as WIP. `rg-memwell-dev` was torn down after step 1, so nothing of this step
exists in Azure yet and both Verify boxes below stay unchecked.

### What is in place

- `infra/modules/postgres.bicep` (new): Flexible Server `pg-<base>-<env>`,
  `B1ms`/Burstable, `version: '16'`, 32 GiB storage, `highAvailability.mode:
'Disabled'`, 7-day backup, `publicNetworkAccess: 'Enabled'`; child resources
  for the `memorywell` database, the `azure.extensions = 'vector'` allowlist,
  and an `allow-client` firewall rule built from `CLIENT_IP`.
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

### Open before the first deploy

1. **`CLIENT_ID` vs `CLIENT_IP` mismatch — blocker.**
   `scripts/common.sh` exports `CLIENT_ID="$(curl -s https://api.ipify.org)"`,
   but `main.bicepparam` reads `CLIENT_IP`. The firewall rule would get an
   empty string and the deployment fails validation. `CLIENT_ID` is also a
   loaded name — it is the usual variable for an Entra service principal's
   client id, so it should not carry a home IP address. Rename the export to
   `CLIENT_IP`.
2. **Comment still owed.** The brief asks for the pooling story in a comment
   (Flexible Server built-in pooler on PG14+; `max_connections` is small on a
   2-vCPU B1ms and Phase 3 opens one pool per agent container). Not written.
3. **Cost guards to keep:** `highAvailability.mode: 'Disabled'` (the ARM
   default is ZoneRedundant — 2× cost, needs zones) and
   `storage.autoGrow: 'Disabled'` (a runaway vector table would otherwise
   resize the server silently). Both are already set.
4. **Cosmetic:** the module param is spelled `adminstratorLogin` (missing `i`).
   Consistent across `postgres.bicep` and the call site, so it compiles.

### Verify

- [ ] `./scripts/deploy.sh what-if` shows the Flexible Server, database,
      `azure.extensions` and firewall rule, and no change to Cosmos.
- [ ] `./scripts/deploy.sh create` succeeds. Expect ~5–10 min of silence while
      B1ms provisions — `deploy.sh` prints nothing between the ARM call and the
      health check.
- [ ] `az postgres flexible-server show -g rg-memwell-dev -n pg-memwell-dev -o table`
      reports `B1ms` / Burstable, HA `Disabled`, `publicNetworkAccess Enabled`.
- [ ] `SELECT * FROM pg_extension WHERE extname='vector'` returns a row — but
      only _after_ step 5 runs `CREATE EXTENSION`. Bicep only allowlists the
      extension; it never installs it. Before the seed, check the allowlist
      instead: `SHOW azure.extensions` should list `vector`.
- [ ] `documents` table exists after the seed runs
      ([step-5.md](./step-5.md)).

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
