# Phase 5 · Step 1 — Scaffold `web/`

## What changed

- Created `web/` using Vite + React + TypeScript (`react-ts` template).
- Installed dependencies; `npm run build` passes.

## Why

Establishes the frontend project location mandated by the plan (plain package
manager inside `web/` only; no pnpm workspace) before any feature work.

## ELI5

This step just unboxes the frontend starter kit so later steps have a place to
live; no app behaviour yet.

## Validate

```bash
cd web && npm install && npm run build
```

Expected: build succeeds and writes `web/dist/`.
