# Phase 6 Step 1 — Transcription worker (stub)

## What changed

- `functions/sb_transcription/__init__.py`: parse JSON payload (`memory_id`, `blob_url`), log, keep DLQ trigger behaviour.
- `docs/phase-6/_brief.md`: new.

## Why

Foundation for voice pipeline; STT integration deferred until SDK/credentials available.

## ELI5

Listens for transcription jobs and logs them; full speech-to-text comes later.

## Validate

```bash
cd functions && python -c "import json; print('ok')"
```

Expected: ok
