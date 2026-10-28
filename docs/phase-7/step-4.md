# Step 4 — KQL workbook and DLQ alert

## What changed

- Added `infra/modules/workbook.bicep` (shared workbook linked to App Insights).
- Added `infra/modules/dlqalert.bicep` (metric alert on dead-lettered messages).
- Wired both into `infra/modules/platform.bicep`.

## Why

Delivers the workbook (incl. flag rate surface) and DLQ alert observability requirements.

## ELI5

A dashboard and an alarm for stuck messages.

## Validate

```bash
./scripts/validate-bicep.sh
```

Expected: all files compile cleanly.
