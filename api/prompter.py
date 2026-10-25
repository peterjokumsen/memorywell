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


def build_prompt(ctx: PromptContext) -> list[dict[str, str]]:
    """Build chat messages for the Prompter given a context."""
    system = get_persona(ctx.persona)
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
