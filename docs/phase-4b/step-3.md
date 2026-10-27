# Step 3 — Embedding wiring (vector field + change-feed hook stub)

## What changed

- Added `embedding` field to `CuratedMemory`.
- Added `generate_embedding` (injectable) and `refresh_embedding` hook.

## Why

Prepares canonical memories for vector search; real embedding call lands in
the change-feed function (Phase 3/7).

## ELI5

Like adding a searchable barcode to each memory card.

## Validate

```bash
cd api && python -m pytest -q
```
