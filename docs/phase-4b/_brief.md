# Phase 4b Brief — Curator

> Status: in progress (2026-10-26). Phase 4a merged.
> Branch: `phase-4b` (from `main`).

## 1. Goal

Implement the **Curator** agent: metadata extraction with structured alias-intent
output, canonical memory write with alias snapshot + embedding wiring, and a
conversation API for recording/retrieving submissions. Guardian validation of
alias requests lands in Phase 4c.

## 2. AI-200 concepts practised

- Azure OpenAI structured outputs (JSON schema) for metadata + alias intent.
- Cosmos DB canonical write with idempotency.
- Embedding generation wiring (change-feed / function hook).
- FastAPI conversation endpoints.

## 3. Ordered steps

| Step | File      | Scope                                                   |
| ---- | --------- | ------------------------------------------------------- |
| 1    | step-1.md | Metadata extraction + structured alias-intent output    |
| 2    | step-2.md | Canonical memory write + alias snapshot + idempotency   |
| 3    | step-3.md | Embedding wiring (vector field + change-feed hook stub) |
| 4    | step-4.md | Conversation API endpoints (record + retrieve)          |
| 5    | step-5.md | Tests + review gate                                     |

## 4. File outline

```plaintext
api/curator.py          # Curator agent: extraction, write, conversation
api/tests/test_curator.py
```

## 5. Review gate

- Curator extracts metadata + alias intent from a submission.
- Canonical memory write is idempotent and snapshots alias.
- Conversation API records and retrieves a memory.
- `pytest` green.
