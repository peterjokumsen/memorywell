# Phase 4c Brief — Guardian

> Status: starting (2026-10-27).
> Branch: `phase-4c` (from `main`).

## 1. Goal

Implement the **Guardian** agent: safety/sensitivity + quality/duplicate scoring on
every new memory, writing a `flag {reason, score, status}` and emitting
`memory.flagged` for the owner review queue; plus alias-request validation
(uniqueness, appropriateness, own-alias-only) with auto-apply on pass and flag on
fail.

## 2. AI-200 concepts practised

- Azure OpenAI lightweight classification / structured-output scoring.
- Service Bus topic trigger (Guardian reviewer) + Event Grid fan-out.
- Cosmos DB flag write + `resolvedBy` audit.

## 3. Ordered steps

| Step | File      | Scope                                                                       |
| ---- | --------- | --------------------------------------------------------------------------- |
| 1    | step-1.md | Classification/scoring: safety, sensitivity, quality, duplicate             |
| 2    | step-2.md | Flag write + `memory.flagged` emission                                      |
| 3    | step-3.md | Alias validation (uniqueness, appropriateness, own-alias-only) + auto-apply |
| 4    | step-4.md | Functions `sb_guardian` wiring + tests + review gate                        |

## 4. File outline

```plaintext
api/guardian.py          # Guardian agent: scoring, flagging, alias validation
api/tests/test_guardian.py
functions/sb_guardian/__init__.py   # SB topic trigger wiring
```

## 5. Review gate

- Guardian scores a new memory and writes a flag when thresholds exceeded.
- `memory.flagged` emitted on create only.
- Alias request validated; pass auto-applies + `alias.updated`; fail flagged.
- `pytest` green.
