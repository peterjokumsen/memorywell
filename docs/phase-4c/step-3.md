# Phase 4c Step 3 — Alias validation + auto-apply

## What changed

Added `validate_alias` and `apply_alias` to `api/guardian.py` plus tests.

## Why

Guardian validates alias requests (uniqueness, appropriateness, own-alias-only);
pass auto-applies + emits alias.updated, fail flags for owner.

## ELI5

Checking a new nickname is allowed before using it.

## Validate

```bash
cd api && pytest tests/test_guardian*.py -q
```
