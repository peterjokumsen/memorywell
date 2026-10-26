# Phase 4a · Step 4 — Single-shot follow-up generation + API endpoint

## What changed

- Added `generate_question` to `api/prompter.py` (Azure OpenAI via httpx, injectable llm for tests).
- Added `POST /prompts` endpoint in `api/main.py`.
- Added test for generation with mock llm.

## Why

Exposes Prompter generation as an API and keeps LLM call injectable/testable.

## ELI5

The endpoint takes contributor context, builds a prompt, asks the AI, and returns one question.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
