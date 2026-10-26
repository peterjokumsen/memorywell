# Phase 4a · Step 2 — RAG retrieval over pgvector with metadata filters

## What changed

- Added `api/rag.py` with `build_filter`, `retrieve` (plus `retrieve_memories`/`search` aliases) and a `retrieve_by_text` placeholder.
- Added `api/tests/test_rag.py`.

## Why

Provides shared, SQL-only retrieval helpers that filter memories by chronicle and contributor metadata and rank by vector similarity, returning plain memory strings for the Prompter.

## ELI5

RAG retrieval is like searching a filing cabinet: we filter by who and which chronicle, then pick the closest matches to a question vector.

## Validate

```bash
cd api && python -m pytest -q
```

Expected: all tests pass.
