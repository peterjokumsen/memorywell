# Phase 6 Step 2 — Blob upload endpoint (stub)

## What changed

- `api/main.py`: added `POST /uploads` accepting a file, returns queued metadata.
- `api/requirements.txt`: added `python-multipart`.

## Why

Entry point for voice/photo pipeline; Service Bus enqueue and blob write deferred.

## ELI5

A door where files can be dropped; it acknowledges receipt.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
