# Phase 6 Step 4 — Upload test

## What changed

- `api/tests/test_main.py`: added `test_upload`.

## Why

Regression coverage for upload endpoint.

## ELI5

Checks the drop door works.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
