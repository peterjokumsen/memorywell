# Phase 2 · Step 5 — Group E: Seed script

**Group E — Seed script (`scripts/seed.py`, new + requirements).** Reads
connection info from env/Key Vault locally, writes: one household; two
chronicles; two `role=owner` membership rows + one Full Contributor + one
Observer; contributor record with owner-managed (`contact`, `relation`,
`status`) and contributor-managed per-chronicle `displayAlias` map +
`promptCadence` map (one `weekly`, one default `monthly`); one memory
snapshotting `contributorId` + `aliasAtWriteTime` +
`promptId`/`parentMemoryId`/`turnCount`/`conversationId`; one row each in
Postgres `documents` and a Redis `PING` + alias-lookup key. Every field
above is schema-only: no last-owner enforcement, no Guardian logic (later
phases). Idempotent (re-runnable: upsert by id).

Stub shape (write it yourself, keep it this small):

```python
# scripts/seed.py — stub
"""Phase 2 seed: one household, idempotent upserts. Usage: python scripts/seed.py"""
HOUSEHOLD = {"id": "hh-seed-1", "name": "Seed Household"}
print("seed stub — implement Group E per this step")
```

## Verify

- [ ] Re-running `seed.py` twice yields identical counts (idempotent).
- [ ] Memory row carries `aliasAtWriteTime`; contributor row carries
      `displayAlias` + `promptCadence` maps.
