# Observability

Consolidated from Phase 7.

## Overview

- OpenTelemetry instrumentation across API, Functions, and worker.
- KQL workbook (including flag rate) in Bicep infra.
- DLQ alert wired into existing monitoring resources.
- App Insights + OTel SDK (traces, metrics, logs); Azure Monitor alerts on Service Bus DLQ depth.
- Structured logging conventions (`scripts/check-logging.sh`).
  "
