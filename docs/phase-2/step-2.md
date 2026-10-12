# Phase 2 · Step 2 — Group B: PostgreSQL + pgvector

**Group B — PostgreSQL (`infra/modules/postgres.bicep`, new).** Flexible
Server, Burstable `B1ms`, smallest storage, one database (`memorywell`),
`vector` extension enabled via server extension allowlist +
`CREATE EXTENSION`. Stub schema only: a `documents` table (`id uuid pk`,
`chronicleId text`, `contributorId text`, `topic text`,
`createdAt timestamptz`, `embedding vector(<dims>)`, `metadata jsonb`)
created by the seed script, not Bicep. Note the pooling story (Flexible
Server built-in pooler) in a comment. Nothing else in this step — no
Cosmos, no Redis.

`vector(<dims>)` must match the vector dimension you recorded in
[step-1.md](./step-1.md).

## Verify

- [ ] `SELECT * FROM pg_extension WHERE extname='vector'` returns a row.
- [ ] `documents` table exists after the seed runs
      ([step-5.md](./step-5.md)).
