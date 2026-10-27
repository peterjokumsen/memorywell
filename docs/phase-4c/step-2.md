# Phase 4c Step 2 — Flag write + memory.flagged emission

## What changed

Added `GuardianFlag`, `build_flag`, `emit_memory_flagged` to `api/guardian.py`
plus tests.

## Why

Guardian persists a flag and emits memory.flagged for the owner review queue.

## ELI5

When something looks off, write a ticket and ring the alarm.

## Validate

```bash
cd api && pytest tests/test_guardian*.py -q
```
