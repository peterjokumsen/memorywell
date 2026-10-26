# Phase 4a · Step 3 — Alias injection + cadence filter

## What changed

- Added `get_alias`, `snapshot_alias`, and `is_due` to `api/prompter.py`.
- `is_due` uses calendar months via `dateutil.relativedelta` for monthly cadence.
- Added `python-dateutil` to `api/requirements.txt`.
- Added tests.

## Why

Alias is injected into prompts and snapshotted for memories; cadence filter suppresses prompts when not due, with special-occasions as manual trigger.

## ELI5

Cadence is a schedule; the filter checks if enough time passed since last memory to ask again.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
