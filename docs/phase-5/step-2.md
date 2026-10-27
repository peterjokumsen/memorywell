# Phase 5 · Step 2 — API client + dev identity

## What changed

- Added `web/src/api/client.ts` with `apiFetch` using `VITE_API_BASE_URL`.
- Added `DevIdentityProvider` and `useDevIdentity` for local dev identity.
- Wired provider in `main.tsx`.

## Why

Frontend needs a single API entry point and an identity context before feature screens.

## ELI5

This step gives the app a phone (API client) and a name tag (dev identity).

## Validate

```bash
cd web && npm run build && npm test
```

Expected: build and tests pass.
