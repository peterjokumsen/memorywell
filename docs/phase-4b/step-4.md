# Step 4 — Conversation API endpoints

## What changed

- Added `record_memory` / `list_memories` helpers in `api/curator.py`.
- Added `POST /memories` and `GET /memories/{chronicle_id}` to `api/main.py`.

## Why

Exposes Curator recording/retrieval as an API.

## ELI5

A front desk to drop off and look up memories.

## Validate

```bash
cd api && python -m pytest -q
```
