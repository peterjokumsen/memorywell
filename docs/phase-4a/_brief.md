# Phase 4a Brief — Prompter

> Status: in progress (2026-10-25). Phase 3 merged.
> Branch: `phase-4a` (from `main`).

## 1. Goal

Implement the **Prompter** agent: persona system prompts, retrieval-augmented
question generation with alias injection, cadence filtering, and single-shot
follow-ups. Multi-turn fields are written but gated off behind a feature flag.

## 2. AI-200 concepts practised

- Azure OpenAI (Foundry) chat completions for persona-driven question generation.
- RAG over pgvector (Postgres) with metadata filters.
- Redis TTL caching for hot memories / alias lookups with invalidation.
- Managed identity auth to OpenAI / Postgres / Redis.

## 3. Ordered steps

| Step | File      | Scope                                             |
| ---- | --------- | ------------------------------------------------- |
| 1    | step-1.md | Persona system prompts + prompt builder           |
| 2    | step-2.md | RAG retrieval over pgvector with metadata filters |
| 3    | step-3.md | Alias injection + cadence filter                  |
| 4    | step-4.md | Single-shot follow-up generation + API endpoint   |
| 5    | step-5.md | Tests + review gate                               |

## 4. File outline

```plaintext
api/prompter.py          # Prompter agent: persona, RAG, generation
api/rag.py               # shared retrieval helpers
api/persona.py           # persona definitions
api/tests/test_prompter.py
```

## 5. Review gate

- Prompter generates a grounded question for a (chronicle, contributor) pair.
- Cadence filter suppresses prompts when not due.
- Alias is injected into the prompt.
- `pytest` green.
