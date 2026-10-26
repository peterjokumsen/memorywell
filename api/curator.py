"""Curator agent: metadata extraction + canonical memory write."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any

import httpx


@dataclass
class CuratedMemory:
    chronicle_id: str
    contributor_id: str
    text: str
    topic: str = ""
    milestone: str | None = None
    date: str | None = None
    alias_at_write_time: str = ""
    alias_change_requested: bool = False
    requested_alias: str | None = None


EXTRACTION_SYSTEM = (
    "You extract structured metadata from a family memory submission. "
    "Return JSON with keys: topic (short), milestone (string or null), "
    "date (ISO date or null), aliasChangeRequested (bool), requestedAlias "
    "(string or null). Only set aliasChangeRequested when the contributor "
    "explicitly asks to be called by a new name."
)


def build_extraction_prompt(text: str) -> list[dict[str, str]]:
    return [
        {"role": "system", "content": EXTRACTION_SYSTEM},
        {"role": "user", "content": text},
    ]


def extract_metadata(text: str, *, llm=None) -> dict[str, Any]:
    messages = build_extraction_prompt(text)
    if llm is not None:
        raw = llm(messages)
        if isinstance(raw, dict):
            return raw
        return json.loads(str(raw))
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
    key = os.getenv("AZURE_OPENAI_API_KEY")
    deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini")
    if not endpoint or not key:
        raise RuntimeError("Azure OpenAI not configured")
    url = (
        f"{endpoint.rstrip('/')}/openai/deployments/{deployment}"
        "/chat/completions?api-version=2024-08-01-preview"
    )
    resp = httpx.post(
        url,
        headers={"api-key": key},
        json={"messages": messages, "response_format": {"type": "json_object"}},
        timeout=30.0,
    )
    resp.raise_for_status()
    data = resp.json()
    content = data["choices"][0]["message"]["content"]
    return json.loads(content)


def to_curated_memory(
    chronicle_id: str,
    contributor_id: str,
    text: str,
    alias: str,
    extracted: dict[str, Any],
) -> CuratedMemory:
    return CuratedMemory(
        chronicle_id=chronicle_id,
        contributor_id=contributor_id,
        text=text,
        topic=str(extracted.get("topic", "") or ""),
        milestone=extracted.get("milestone"),
        date=extracted.get("date"),
        alias_at_write_time=alias,
        alias_change_requested=bool(extracted.get("aliasChangeRequested", False)),
        requested_alias=extracted.get("requestedAlias"),
    )
