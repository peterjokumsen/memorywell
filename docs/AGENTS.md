# Agents

Consolidated from Phases 4a–4c.

## Execution mode

Phase documentation (brief + step docs) is authored during planning. Once
documented, the agent implements the entire phase on a single branch named
`phase-<n>-<brief-description>`, runs the local gates, records the
`## What changed` / `## Why` / `## ELI5` / `## Validate` sections, and opens
one PR for the whole phase. The human validates and merges; the agent never
merges. No per-step branches or PRs.

## Phase 4a — Prompter

- Persona system prompts, retrieval-augmented question generation with alias injection.
- Cadence filtering, single-shot follow-ups.
- Multi-turn fields written but gated behind feature flag.

## Phase 4b — Curator

- Metadata extraction with structured alias-intent output.
- Canonical memory write with alias snapshot + embedding wiring.
- Conversation API for recording/retrieving submissions.
- Guardian validation of alias requests lands in Phase 4c.

## Phase 4c — Guardian

- Safety/sensitivity + quality/duplicate scoring on every new memory.
- Writes `flag {reason, score, status}` and emits `memory.flagged` for owner review queue.
- Alias-request validation (uniqueness, appropriateness, own-alias-only) with auto-apply on pass and flag on fail.
  "
