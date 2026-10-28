# Step 1 — OpenTelemetry instrumentation (API)

## What changed

- Added `api/telemetry.py` with `configure_telemetry(app)` that sets up a
  `TracerProvider` (OTLP HTTP exporter when `OTEL_EXPORTER_OTLP_ENDPOINT` is
  set, otherwise console only when `OTEL_CONSOLE_EXPORT` is enabled) and
  instruments the FastAPI app via `FastAPIInstrumentor`. Best-effort: no-op if
  OpenTelemetry packages are missing.
- Wired `configure_telemetry(app)` into `api/main.py`.
- Added OpenTelemetry packages to `api/requirements.txt`.

## Why

Provides request/dependency traces for the API as the first half of the
phase-7 observability goal, without breaking tests in minimal environments.

## ELI5

OpenTelemetry is like adding a flight recorder to the API: every request gets a
trace with timing, so we can see what happened and where time went.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
