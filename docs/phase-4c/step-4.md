# Phase 4c Step 4 — Functions wiring + tests + review gate

## What changed

Updated `functions/sb_guardian/__init__.py` to parse payload and log scoring.

## Why

Wire Guardian into Service Bus topic trigger.

## ELI5

The doorbell now calls the inspector.

## Validate

```bash
cd api && pytest -q
```
