# Phase 4a · Step 5 — Tests + review gate

## What changed

- Added `api/tests/test_api.py` for `/prompts` endpoint.
- Added `bruno/api/prompt.yml` manual request.

## Why

Completes test coverage for Prompter generation flow and manual validation.

## ELI5

We added a smoke test for the HTTP endpoint and a Bruno request to try it by hand.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
