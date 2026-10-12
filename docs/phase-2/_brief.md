# Phase 2 Brief — Data Layer

> Status: not started (2026-10-11). Phase 1 merged (`7892fec`, PR #3).
> Branch: `phase-2-data-layer` (from `origin/main`). Human builds by hand.
> Agent unblocks only.
>
> Layout: one `step-x.md` per ordered step in this directory; each step file
> carries its own instructions, stub shapes/notes, and verification checks.

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

| Step | File                   | Group                                                       |
| ---- | ---------------------- | ----------------------------------------------------------- |
| 1    | [step-1.md](step-1.md) | Group A — Cosmos DB (containers, consistency, vector index) |
| 2    | [step-2.md](step-2.md) | Group B — PostgreSQL Flexible Server + pgvector             |
| 3    | [step-3.md](step-3.md) | Group C — Redis                                             |
| 4    | [step-4.md](step-4.md) | Group D — Secrets wiring into Key Vault                     |
| 5    | [step-5.md](step-5.md) | Group E — Seed script                                       |
| 6    | [step-6.md](step-6.md) | Deploy + hygiene                                            |

Do not start a step before the previous one verifies. No Phase 3 work starts
until the §6 review gate passes.

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
docs/phase-2/                 # this brief (_brief.md) + one step-x.md per step
```

## 6. Review gate (demo before Phase 3)

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
