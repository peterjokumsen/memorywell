# Phase 7 Brief — Observability

> Status: in progress (2026-10-28). Phase 6 merged.

## Goal

Add end-to-end observability: OpenTelemetry instrumentation across API, Functions,
and worker; a KQL workbook (including flag rate) in the Bicep infra; and a DLQ
alert wired into the existing monitoring resources.

## AI-200 concepts

- Application Insights + OpenTelemetry SDK (traces, metrics, logs)
- KQL workbooks for operational dashboards
- Azure Monitor alerts on Service Bus DLQ depth
- Structured logging conventions (see `scripts/check-logging.sh`)

## Ordered steps

1. OpenTelemetry instrumentation in API (`api/`) — request + dependency traces, custom spans.
2. Application Insights Bicep module + connection string injected into API container app (and Functions).
3. OpenTelemetry instrumentation in Functions (`functions/`) — triggers + dependency traces.
4. KQL workbook Bicep module (incl. flag rate) + deploy wiring.
5. DLQ alert Bicep module + deploy wiring.
6. Tests / validation (logging gate, bicep build).

## Review gate

- Traces visible end-to-end for a memory upload + transcription flow
- Workbook renders flag rate panel
- DLQ alert fires on a seeded dead-lettered message
- `./scripts/check-logging.sh` green
