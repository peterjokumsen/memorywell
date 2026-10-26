"""Prompter agent: persona-driven, retrieval-grounded question generation.

This module is the single entry point for the Prompter. It builds a prompt from
a persona, the contributor's alias, and retrieved memories, then (in later
steps) calls Azure OpenAI to generate a question.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from dateutil.relativedelta import relativedelta

from persona import get_persona


@dataclass
class PromptContext:
    chronicle_id: str
    contributor_id: str
    alias: str
    persona: str = "warm-family"
    memories: list[str] = field(default_factory=list)
    mode: str = "checkin"
    new_memory: str | None = None


def build_prompt(ctx: PromptContext) -> list[dict[str, str]]:
    """Build chat messages for the Prompter given a context.

    ``mode="checkin"`` (default) invites a new memory grounded in retrieved
    memories. ``mode="followup"`` asks a question anchored on ``new_memory``.
    """
    system = get_persona(ctx.persona)
    if ctx.mode == "followup" and ctx.new_memory:
        user = (
            f"Contributor alias: {ctx.alias}\n"
            f"Chronicle: {ctx.chronicle_id}\n"
            f"New memory just shared: {ctx.new_memory}\n"
            "Ask one short question that digs into a detail or feeling from that "
            "memory."
        )
    else:
        memory_block = "\n".join(f"- {m}" for m in ctx.memories) or "(none)"
        user = (
            f"Contributor alias: {ctx.alias}\n"
            f"Chronicle: {ctx.chronicle_id}\n"
            f"Relevant memories:\n{memory_block}\n"
            "Ask one short question that invites a new memory."
        )
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]


def get_alias(contributor: Any, chronicle_id: str) -> str:
    """Return the contributor's per-chronicle display alias."""
    aliases = getattr(contributor, "displayAlias", None)
    if aliases is None and isinstance(contributor, dict):
        aliases = contributor.get("displayAlias", {})
    aliases = aliases or {}
    if isinstance(aliases, dict):
        if chronicle_id in aliases:
            return str(aliases[chronicle_id])
        if aliases:
            return str(next(iter(aliases.values())))
    return str(contributor) if not isinstance(contributor, dict) else "Contributor"


def snapshot_alias(alias: str) -> str:
    """Return the alias to freeze as ``aliasAtWriteTime`` on a new memory."""
    return alias


def is_due(
    cadence: str,
    last_at: datetime | None,
    now: datetime | None = None,
) -> bool:
    """Whether a prompt is due for the given cadence and last activity."""
    if now is None:
        now = datetime.now(UTC)
    if cadence in ("none", "special-occasions"):
        return False
    if last_at is None:
        return True
    if last_at.tzinfo is None:
        last_at = last_at.replace(tzinfo=UTC)
    if cadence == "weekly":
        return now >= last_at + timedelta(days=7)
    if cadence == "monthly":
        return now >= last_at + relativedelta(months=1)
    return False


def generate_question(ctx: PromptContext, *, llm=None) -> str:
    """Generate a single-shot question for the given context."""
    messages = build_prompt(ctx)
    if llm is not None:
        return str(llm(messages))
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
    key = os.getenv("AZURE_OPENAI_API_KEY")
    deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini")
    if not endpoint or not key:
        raise RuntimeError("Azure OpenAI not configured")
    url = (
        f"{endpoint.rstrip('/')}/openai/deployments/{deployment}"
        "/chat/completions?api-version=2024-08-01-preview"
    )
    resp = httpx.post(url, headers={"api-key": key}, json={"messages": messages}, timeout=30.0)
    resp.raise_for_status()
    data = resp.json()
    return data["choices"][0]["message"]["content"]
