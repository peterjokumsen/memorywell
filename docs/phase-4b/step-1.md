# Step 1 — Metadata extraction + structured alias-intent output

## What changed

- Added `api/curator.py` with `CuratedMemory`, `build_extraction_prompt`,
  `extract_metadata` (llm-injectable, Azure OpenAI fallback with JSON mode),
  and `to_curated_memory`.

## Why

Curator's first job is to turn a raw submission into structured metadata
(topic, milestone, date) plus an alias-intent signal, so downstream Guardian
can validate rename requests.

## ELI5

Like a librarian reading a letter and writing a card catalog entry plus noting
"they want to be called Granny now."

## Validate

```bash
cd api && python -c "import curator; print('ok')" && pytest -q
```
