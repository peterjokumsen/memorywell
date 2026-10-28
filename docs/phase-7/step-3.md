# Step 3 — OpenTelemetry instrumentation (Functions)

## What changed

- `functions/function_app.py` calls `configure_azure_monitor` when
  `APPLICATIONINSIGHTS_CONNECTION_STRING` is set (best-effort import).
- Added `azure-monitor-opentelemetry` to `functions/requirements.txt`.

## Why

Captures traces for Function triggers and dependencies in Application Insights.

## ELI5

Same flight recorder as the API, but for the background Functions.

## Validate

```bash
cd functions && python -c "import function_app" 2>&1 | tail
```

Expected: no import errors (azure-monitor-opentelemetry optional).
