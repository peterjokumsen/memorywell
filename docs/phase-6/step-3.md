# Phase 6 Step 3 — Blob containers

## What changed

- `infra/modules/storage.bicep`: added `voice-notes` and `photos` containers.

## Why

Storage targets for voice/photo pipeline.

## ELI5

Two folders in blob storage for voice notes and photos.

## Validate

```bash
az bicep build --file infra/modules/storage.bicep && az bicep build --file infra/main.bicep
```

Expected: no errors.
