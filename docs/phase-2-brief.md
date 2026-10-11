# Phase 2 Brief — Data Layer

> Status: not started (2026-10-11). Phase 1 merged (`7892fec`, PR #3).
> Branch: `phase-2-data-layer` (from `origin/main`). Human builds by hand.
> Agent unblocks only.

## 1. Goal

Provision the three Phase 1–deferred data stores with Bicep and seed them
with invariant-correct sample data. No agents, no API data clients, no
messaging — those are Phases 3–4.

Deploys, each as its own group (one step per group, no mixing):

- **Group A — Cosmos DB for NoSQL**: account, database, containers.
- **Group B — PostgreSQL Flexible Server**: server, database, pgvector.
- **Group C — Redis**: cache instance.
- **Group D — Secrets wiring**: connection strings / keys into Key Vault.
- **Group E — Seed script**: one household of sample data carrying every
  domain-invariant field.

Out of scope: Service Bus, Event Grid, Functions, agents (4a–4c),
frontend, voice/photo, embedding generation (change feed comes in
Phase 3). No pre-building later phases.

## 2. AI-200 concepts practised

- Data management services: Cosmos DB SDK-ready containers with tuned
  **indexing policy**, chosen **consistency level**, and a **vector index**
  for later semantic search.
- PostgreSQL with **pgvector** as the primary RAG store (schema stubbed,
  retrieval comes in Phase 4a); server-level pooling noted.
- Redis provisioned for the TTL-caching + recent-similarity role it takes
  in later phases; Phase 2 only proves connectivity.
- Secure: data-plane keys land in Key Vault, never in repo or Bicep
  outputs in plaintext.

## 3. Prerequisites

- Phase 1 merged; clean `git status` on `phase-2-data-layer`.
- `az login` works; `.env` has `BASE_NAME`/`ENVIRONMENT`/`LOCATION`
  (`westeurope`, established Phase 1)/`SUBSCRIPTION_ID`.
- Read: `docs/PLAN.md` §§ Architecture §2, Build phases row 2, Cost &
  safety; `AGENTS.md` §§ Domain invariants, Repo rules.

## 4. Ordered steps (human builds, one group per step)

1. **Group A — Cosmos DB (`infra/modules/cosmos.bicep`, new).**
   Account (serverless capability, cheapest tier), one database
   (`memorywell`), containers: `households`, `chronicles`, `contributors`,
   `invites`, `prompts`, `memories`, `transcripts`, `flags`,
   `aliasHistory`. Partition keys: `/householdId` for household-scoped
   containers, `/chronicleId` for chronicle-scoped ones (`memories`,
   `prompts`, `transcripts`, `flags`, `aliasHistory`). Consistency:
   `Session`. Indexing policy: default + excluded paths for large
   blob-payload fields if you add any (keep default otherwise and note
   why). Vector index on `memories.embedding` (flat index, cosine;
   dimensions recorded in §5 — suggested `1536` for
   `text-embedding-3-small`, your choice, document it). Nothing else in
   this step — no Postgres, no Redis, no secrets.
2. **Group B — PostgreSQL (`infra/modules/postgres.bicep`, new).**
   Flexible Server, Burstable `B1ms`, smallest storage, one database
   (`memorywell`), `vector` extension enabled via server extension
   allowlist + `CREATE EXTENSION`. Stub schema only: a `documents` table
   (`id uuid pk`, `chronicleId text`, `contributorId text`, `topic text`,
   `createdAt timestamptz`, `embedding vector(<dims>)`, `metadata jsonb`)
   created by the seed script, not Bicep. Note the pooling story
   (Flexible Server built-in pooler) in a comment. Nothing else in this
   step — no Cosmos, no Redis.
3. **Group C — Redis (`infra/modules/redis.bicep`, new).**
   Cheapest Basic SKU, `westeurope`, TLS-only. No VNet/firewall rules in
   Phase 2 (dev-only public endpoint; note prod hardening as a comment
   for Phase 8). Prove `PING` from the seed script. Nothing else in this
   step.
4. **Group D — Secrets wiring (edit `infra/modules/platform.bicep` +
   `infra/modules/vault.bicep` only).** Store three secrets in the
   existing Key Vault: Cosmos connection string (or endpoint + key
   pair), Postgres connection string, Redis connection string. Grant the
   existing API user-assigned identity `Key Vault Secrets User` (reuse
   the pattern in `vault.bicep`) — no new identity. Bicep must not emit
   secrets in outputs. This step touches only secret plumbing.
5. **Group E — Seed script (`scripts/seed.py`, new + requirements).**
   Reads connection info from env/Key Vault locally, writes: one
   household; two chronicles; two `role=owner` membership rows + one
   Full Contributor + one Observer; contributor record with owner-managed
   (`contact`, `relation`, `status`) and contributor-managed
   per-chronicle `displayAlias` map + `promptCadence` map (one `weekly`,
   one default `monthly`); one memory snapshotting `contributorId` +
   `aliasAtWriteTime` + `promptId`/`parentMemoryId`/`turnCount`/
   `conversationId`; one row each in Postgres `documents` and a Redis
   `PING` + alias-lookup key. Every field above is schema-only: no
   last-owner enforcement, no Guardian logic (later phases). Idempotent
   (re-runnable: upsert by id).
6. **Deploy + hygiene.** `az bicep build --file infra/main.bicep`,
   `./scripts/deploy.sh` (extends Bicep composition only — do not add a
   container revision path here), verify per §6, `scripts/teardown.sh`
   still destroys everything. `.env` stays ignored; seed reads secrets
   from env, never hardcodes.

## 5. File outline (stubs, not implementations)

```plaintext
infra/modules/cosmos.bicep    # Group A: serverless account + db + 9 containers, Session consistency, vector index
infra/modules/postgres.bicep  # Group B: Burstable B1ms server + db + vector extension allowlist
infra/modules/redis.bicep     # Group C: Basic SKU cache, TLS-only
infra/modules/platform.bicep  # + cosmos/postgres/redis composition (edit only)
infra/modules/vault.bicep     # + 3 secret writes, reuse Secrets User pattern (edit only)
scripts/seed.py               # Group E: idempotent seed (Cosmos + Postgres + Redis ping)
scripts/seed-requirements.txt # azure-cosmos, psycopg[binary], redis (pinned)
.env.example                  # + COSMOS_/POSTGRES_/REDIS_ var names (no values/secrets)
docs/phase-2-brief.md         # this file
```

Vector dimensions (record your choice here when you build): suggested
`1536` (`text-embedding-3-small`, used by Curator in Phase 4b). Cosmos
vector path `memories.embedding` and Postgres `embedding
vector(<dims>)` must use the same number.

Stub shapes (write them yourself, keep them this small):

```bicep
// infra/modules/cosmos.bicep — stub
resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'cosmos-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  kind: 'GlobalDocumentDB'
  properties: {
    capabilities: [{ name: 'EnableServerless' }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: inputs.global.location, failoverPriority: 0 }]
  }
}
```

```python
# scripts/seed.py — stub
"""Phase 2 seed: one household, idempotent upserts. Usage: python scripts/seed.py"""
HOUSEHOLD = {"id": "hh-seed-1", "name": "Seed Household"}
print("seed stub — implement Group E per §4 step 5")
```

## 6. Manual verification checks

- [ ] Group A: portal/CLI shows Cosmos serverless account + 9 containers;
  `memories` has vector index; consistency `Session`.
- [ ] Group B: `SELECT * FROM pg_extension WHERE extname='vector'` returns
  a row; `documents` table exists after seed.
- [ ] Group C: Redis `PING` → `PONG` (from seed output or `redis-cli`).
- [ ] Group D: three secrets present in `kv-<base>-<env>`; Bicep outputs
  contain no secret values; API identity holds Secrets User.
- [ ] Group E: re-running `seed.py` twice yields identical counts
  (idempotent); memory row carries `aliasAtWriteTime`; contributor row
  carries `displayAlias` + `promptCadence` maps.
- [ ] `scripts/teardown.sh --purge-vault` still destroys everything;
  `git status --short` shows no `.env`, no secrets.

## 7. Review gate (demo before Phase 3)

Paste back into chat:

1. Cosmos container list + `memories` index/vector policy excerpt.
2. `pg_extension` vector row + `documents` row count after seed.
3. Seed log (second run proving idempotency) + Redis `PONG`.
4. Key Vault secret list (names only, never values).
5. `git status --short` + `git log --oneline -5`.
6. One paragraph: partition-key choices, vector-dimension choice, and what
   you'd do differently.

Agent sanity-checks the above, then issues the Phase 3 brief. No Phase 3
work starts until the gate passes. Cost reminder: destroy resources
between sessions (`scripts/teardown.sh --purge-vault`); Phase 2 adds ≈
Cosmos serverless (request-charged) + Postgres B1ms + Redis Basic.
