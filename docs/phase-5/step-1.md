# Phase 5 · Step 1 — Scaffold `web/`

## What changed

- Created `web/` using Vite + React + TypeScript (`react-ts` template).
- Added Vitest + Testing Library test setup with `npm test`.
- Installed dependencies; `npm run build` and `npm test` pass.

## Why

Establishes the frontend project location mandated by the plan (plain package
manager inside `web/` only; no pnpm workspace) before any feature work, with a
test runner available from the start.

## ELI5

This step just unboxes the frontend starter kit so later steps have a place to
live; no app behaviour yet.

## Validate

```bash
cd web && npm install && npm run build && npm test
```

Expected: build succeeds, tests pass.
