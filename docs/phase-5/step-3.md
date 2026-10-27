# Phase 5 · Step 3 — Invite claim flow

## What changed

- Added `InviteClaim` component calling `POST /api/invites/claim`.
- Rendered in `App`.

## Why

Implements invite claim UI from phase plan.

## ELI5

A form to paste an invite token and claim membership.

## Validate

```bash
cd web && npm run build && npm test
```

Expected: build and tests pass.
