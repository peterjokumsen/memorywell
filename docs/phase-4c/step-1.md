# Phase 4c Step 1 — Classification/scoring

## What changed

Added `api/guardian.py` with `GuardianScore` and `score_memory()` (safety,
sensitivity, quality, duplicate scoring) plus tests in `api/tests/test_guardian.py`.

## Why

Guardian's first job is to score every new memory before flagging.

## ELI5

Like a safety inspector rating each memory on a few simple scales.

## Validate

```bash
cd api && pytest tests/test_guardian.py -q
```
