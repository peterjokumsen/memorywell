"""OpenTelemetry setup for the Memorywell API."""

from __future__ import annotations

import os

from fastapi import FastAPI


def configure_telemetry(app: FastAPI) -> None:
    """Configure tracing for the FastAPI app.

    Instrumentation is best-effort: if the OpenTelemetry packages are missing
    (e.g. minimal test environments) this is a no-op.
    """
    try:
        from opentelemetry import trace
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import (
            BatchSpanProcessor,
            ConsoleSpanExporter,
        )
    except ImportError:  # pragma: no cover - optional dependency
        return

    service_name = os.getenv("OTEL_SERVICE_NAME", "memorywell-api")
    provider = TracerProvider(resource=Resource.create({"service.name": service_name}))

    conn_str = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if conn_str:
        try:
            from azure.monitor.opentelemetry import configure_azure_monitor

            configure_azure_monitor(connection_string=conn_str)
            FastAPIInstrumentor.instrument_app(app)
            app.state.tracer = trace.get_tracer(service_name)
            return
        except ImportError:  # pragma: no cover
            pass

    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if endpoint:
        try:
            from opentelemetry.exporter.otlp.proto.http.trace_exporter import (
                OTLPSpanExporter,
            )

            provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint)))
        except ImportError:  # pragma: no cover
            provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    else:
        # Local/dev: emit to console only when explicitly requested.
        if os.getenv("OTEL_CONSOLE_EXPORT", "").lower() in {"1", "true", "yes"}:
            provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))

    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app)
    app.state.tracer = trace.get_tracer(service_name)


def get_tracer(app: FastAPI):
    return getattr(getattr(app, "state", None), "tracer", None)
