"""Guardian agent: safety/sensitivity + quality/duplicate scoring."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass

from openai import AzureOpenAI


@dataclass
class GuardianScore:
    safety: float = 0.0
    sensitivity: float = 0.0
    quality: float = 1.0
    duplicate: float = 0.0
    reasons: list[str] | None = None

    def __post_init__(self) -> None:
        if self.reasons is None:
            self.reasons = []

    @property
    def flagged(self) -> bool:
        return (
            self.safety >= 0.7
            or self.sensitivity >= 0.7
            or self.duplicate >= 0.8
            or self.quality < 0.3
        )


SCORING_SYSTEM = (
    "You score a family memory submission for safety, sensitivity, quality, "
    "and duplicate-likelihood. Return JSON with keys: safety (0-1), "
    "sensitivity (0-1), quality (0-1), duplicate (0-1), reasons (list of "
    "short strings)."
)


def build_scoring_prompt(text: str) -> list[dict[str, str]]:
    return [
        {"role": "system", "content": SCORING_SYSTEM},
        {"role": "user", "content": text},
    ]


def score_memory(text: str, *, llm=None) -> GuardianScore:
    messages = build_scoring_prompt(text)
    if llm is not None:
        raw = llm(messages)
        if isinstance(raw, dict):
            data = raw
        else:
            data = json.loads(str(raw))
    else:
        endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        key = os.getenv("AZURE_OPENAI_API_KEY")
        deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini")
        if not endpoint or not key:
            raise RuntimeError("Azure OpenAI not configured")
        client = AzureOpenAI(
            azure_endpoint=endpoint,
            api_key=key,
            api_version="2024-08-01-preview",
        )
        resp = client.chat.completions.create(
            model=deployment,
            messages=messages,
            response_format={"type": "json_object"},
        )
        content = resp.choices[0].message.content
        data = json.loads(content)
    return GuardianScore(
        safety=float(data.get("safety", 0.0)),
        sensitivity=float(data.get("sensitivity", 0.0)),
        quality=float(data.get("quality", 1.0)),
        duplicate=float(data.get("duplicate", 0.0)),
        reasons=list(data.get("reasons", []) or []),
    )
