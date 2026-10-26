"""Prompter agent: persona-driven, retrieval-grounded question generation.

This module is the single entry point for the Prompter. It builds a prompt from
a persona, the contributor's alias, and retrieved memories, then (in later
steps) calls Azure OpenAI to generate a question.
"""

from __future__ import annotations

from dataclasses import dataclass, field

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
