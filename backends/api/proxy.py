"""Proxy helpers so the BFF can forward requests to upstream services."""

import os
from typing import Any

import httpx

SERVICES_BASE_URL = os.getenv("SERVICES_BASE_URL", "http://localhost:8000").rstrip("/")
FUNCTIONS_BASE_URL = os.getenv("FUNCTIONS_BASE_URL", "http://localhost:7071").rstrip("/")


async def forward(
    base_url: str,
    path: str,
    method: str = "GET",
    *,
    params: dict[str, Any] | None = None,
    json_body: Any = None,
    headers: dict[str, str] | None = None,
) -> httpx.Response:
    async with httpx.AsyncClient(timeout=30.0) as client:
        return await client.request(
            method,
            f"{base_url}{path}",
            params=params,
            json=json_body,
            headers=headers or {},
        )
