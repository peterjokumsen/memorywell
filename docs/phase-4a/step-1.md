# Phase 4a · Step 1 — Persona system prompts + prompt builder

## What changed

- Added `api/persona.py` with persona system prompts and `get_persona`.
- Added `api/prompter.py` with `PromptContext` and `build_prompt`.
- Added `api/tests/test_prompter.py`.

## Why

Establishes the Prompter's prompt construction surface before retrieval and
generation are wired in later steps.

## ELI5

A persona is just a character the AI plays; the prompt builder assembles that
character's instructions plus what we know about the contributor into a message
the AI can answer.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
