# Step 2 — Application Insights Bicep wiring

## What changed

- Added `infra/modules/appinsights.bicep` (Microsoft.Insights/components) linked to the Log Analytics workspace.
- Wired it into `infra/modules/platform.bicep` and passed its connection string to the container app and Functions modules.
- Container app + Functions now set `APPLICATIONINSIGHTS_CONNECTION_STRING`.
- API telemetry uses Azure Monitor OpenTelemetry when the connection string is present.

## Why

Makes the step-1 instrumentation actually export to Application Insights.

## ELI5

App Insights is the dashboard; this step plugs the API and Functions into it.

## Validate

```bash
./scripts/validate-bicep.sh && cd api && python -m pytest -q
```
