# Step 2 — Canonical memory write + alias snapshot + idempotency

## What changed

- Added `memory_key` and `write_memory` to `api/curator.py`: idempotent
  canonical write keyed by (chronicle, contributor, text), returning the
  existing memory on duplicate.

## Why

Curator must write the canonical memory once; retries/replays should not
create duplicates. Alias snapshot is already frozen in `CuratedMemory`.

## ELI5

Like a librarian who checks the card catalog before filing a new card.

## Validate

```bash
cd api && python -m pytest -q
```
