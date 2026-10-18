# Phase 2 · Step 5 — Group E: Seed script

**Group E — Seed script (`scripts/seed.py`, `scripts/seed-requirements.txt`, both
new).** Owns both the Postgres schema and the sample data. Human builds by hand.

## Decisions already made (do not re-litigate)

| Decision                     | Choice                                                                       | Why                                                                                                                                                                 |
| ---------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Postgres + Redis credentials | **Read from Key Vault** via `DefaultAzureCredential`                         | Same path the app uses. `postgres-connection-string` + `redis-url` exist; your `Key Vault Secrets Officer` role on the RG subsumes `Secrets User`, so no new grant. |
| Cosmos auth                  | **`DefaultAzureCredential`**                                                 | Account has `disableLocalAuth: true`; there is no key to use. Your principal holds the data-plane role.                                                             |
| Cosmos endpoint + database   | **From env** (`COSMOS_ENDPOINT`, `COSMOS_DATABASE`, exported by `common.sh`) | Derivable, no `az` round-trip. Not secrets, so not in Key Vault.                                                                                                    |
| `documents` table            | **Created by `seed.py`**, not Bicep                                          | There is no ARM resource type that executes SQL against a Flexible Server. `deploymentScripts` would boot an ACI per run for one table.                             |
| Embedding dimension          | **1536**                                                                     | Matches the Cosmos vector index (`cosmos.bicep`), so one model and one embedding call feed both stores.                                                             |

## 1. Dependencies

`scripts/seed-requirements.txt`, pinned:

```
azure-identity==1.19.0
azure-cosmos==4.9.0
azure-keyvault-secrets==4.7.0
psycopg[binary]==3.2.3
redis==5.2.1
```

Install into a venv (never globally): `python -m venv .venv && .venv/bin/pip install -r scripts/seed-requirements.txt`.

## 2. Resolve config in this order

1. `source scripts/common.sh` → gives you `COSMOS_ENDPOINT`, `COSMOS_DATABASE`,
   `COSMOS_ACCOUNT_NAME`, `VAULT_NAME` as env vars. The Python script reads
   `os.environ` — do not re-derive the names in Python or they will drift.
2. `SecretClient(vault_url=f"https://{VAULT_NAME}.vault.azure.net",
credential=DefaultAzureCredential())` → `get_secret("postgres-connection-string").value`
   and `get_secret("redis-url").value` (renamed from `redis-connection-string`
   in Step 3, when the stored value became a URL). Never print these.
3. Cosmos: `CosmosClient(COSMOS_ENDPOINT, credential=DefaultAzureCredential())`,
   then `get_database_client(COSMOS_DATABASE)`.

Note the asymmetry, and do not "fix" it: Postgres and Redis arrive as
connection _strings_ (password inside), while Cosmos has no string at all —
just endpoint + database, authenticated by identity.

Both of those values are URLs — `postgresql://…?sslmode=require` and
`rediss://…` — so each goes straight into `psycopg.connect()` /
`Redis.from_url()` with no parsing. Postgres used to store an ADO.NET
`Host=…;Port=…;Database=…` string, which psycopg 3 rejects outright
(`invalid connection option "Host"`): psycopg accepts only a URI or libpq
keyword/value conninfo.

## 3. Schema first, then data

The schema is **already specified** in [step-2.md](./step-2.md) — implement it
verbatim rather than inventing your own:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

Step 2's `azure.extensions = 'vector'` allowlist makes the extension _permitted_,
not _installed_, so this statement is required rather than optional.

```sql
CREATE TABLE IF NOT EXISTS documents (
  id             uuid PRIMARY KEY,
  "chronicleId"  text,
  "contributorId" text,
  topic          text,
  "createdAt"    timestamptz,
  embedding      vector(1536),
  metadata       jsonb
);
```

Idempotent by construction (`IF NOT EXISTS`), so re-running is safe and a torn-down
Postgres self-heals. Step 2 explicitly assigns schema ownership to this step
(`step-2.md:9`, `:20-21`).

Two details that follow from the spec rather than from taste:

- **Quoted camelCase identifiers.** Postgres folds unquoted identifiers to
  lowercase, so `"chronicleId"` and `chronicleid` are different columns. The
  schema is camelCase to match the Cosmos containers; quote it.
- **`metadata jsonb` is the flexible half.** Steps 4a/4b filter retrieval by
  chronicle and contributor (`PLAN.md:67-68`), and `topic` is a separate column
  because those filters ride on it. Keep both; do not fold `topic` into
  `metadata`.

## 4. Sample data (per `AGENTS.md` domain invariants)

One household, two chronicles, and membership that exercises the role set:

- **2 owners** + 1 Full Contributor + 1 Observer (4 membership rows).
- A **contributors** doc with owner-managed fields (`contact`, `relation`,
  `status`) _and_ contributor-managed per-chronicle maps: `displayAlias` +
  `promptCadence` (one `weekly`, one default `monthly`).
- One **memory** snapshotting `contributorId`, `aliasAtWriteTime`, plus
  `promptId` / `parentMemoryId` / `turnCount` / `conversationId` (schema is
  multi-turn-ready even though the flow is single-shot).
- Postgres `documents`: one row mirroring that memory. `id` is a `uuid`, so it
  gets its own id rather than the Cosmos doc id — the two stores key
  independently. Derive it as `uuid.uuid5(uuid.NAMESPACE_URL, cosmos_doc_id)`,
  **not** `uuid4()`: the row is upserted on `id`, so the id has to be stable
  across runs or `ON CONFLICT` never fires and every run appends another row,
  breaking the run-twice check below.
- Redis: `PING` → `PONG`, plus an alias-lookup key.

Schema only — **no** last-owner enforcement and **no** Guardian logic (Phases 3+).

All Cosmos writes must be **upserts keyed by `id`**, not creates. The verify check
runs the script twice and compares counts; a plain `create_item` raises 409 on the
second run.

## Stub shape (keep it this small)

```python
# scripts/seed.py — stub
"""Phase 2 seed: schema + one household, idempotent upserts.

Usage:  source scripts/common.sh && .venv/bin/python scripts/seed.py
"""
print("seed stub — implement Group E per this step")
```

## Verify

Run `./scripts/verify-seed.sh` — it checks everything below against the live
stores, read-only, and exits 1 if any check fails. It exists because the list
used to be prose to go and interpret by hand, and `\d documents` in particular
is not runnable here: step-2.md established there is no local `psql`, so the
script reads `information_schema.columns` through the venv's psycopg instead.

- [x] Re-running twice yields identical counts (idempotency proof).
- [x] Memory row carries `aliasAtWriteTime`; contributor row carries both the
      owner-managed fields and the `displayAlias` + `promptCadence` maps.
- [x] The `documents` table matches `step-2.md:6-8` — 7 columns,
      `embedding vector(1536)`, `metadata jsonb`, camelCase preserved.
- [x] Redis `PING` → `PONG`.
- [x] `pg_extension` still lists `vector` (Step 2 allowlist not regressed).

## Cost

No new infrastructure — the seed writes to stores that already exist. Still run
`./scripts/teardown.sh --purge-vault` between study sessions.
