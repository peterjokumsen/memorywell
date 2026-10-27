# Phase 5 Brief — Frontend

> Status: in progress (2026-10-27). Phase 4c merged.

## Goal

Build the static web frontend (Vite + React) that consumes the existing API/Functions:
Drop Zone, invite claim, alias/cadence pickers, chat UI, voice/photo capture,
timeline with threads/chapters, and the owner review queue. Easy Auth wiring is
prepared for productization; local dev uses a dev identity header.

## AI-200 concepts

- Static web frontend on Azure App Service (env vars + Key Vault references)
- App Service Easy Auth (Microsoft accounts + household membership)
- Container Apps remain the API host; frontend calls it via configured base URL

## Prerequisites

- Phases 1–4c merged on `main`
- API running locally (`api/`) or deployed Container App URL
- `.env` with `VITE_API_BASE_URL`

## Ordered steps

1. Scaffold `web/` (Vite + React + TS) with lint/test scripts; no pnpm workspace.
2. API client + auth/dev identity context.
3. Invite claim flow.
4. Contributor settings: alias picker + cadence picker.
5. Chat UI + Drop Zone (text/photo/voice capture).
6. Timeline with Contributor Threads + Milestone Chapters.
7. Owner review queue.
8. Web testing improvements (per-component tests, API client tests).
9. Easy Auth wiring (placeholder provider).
10. UI/UX polish (responsive layout, theming, accessibility).
11. App Service Bicep module + deploy wiring (Easy Auth).

## File outline

- `web/` (package.json, vite.config, src/...)
- `infra/modules/appservice.bicep` (step 8)
- `docs/phase-5/step-*.md`

## Review gate

- `npm run build` green; `npm test` green
- Invite claim → household membership visible
- Alias rename + cadence change round-trip
- Voice/photo upload surfaces in timeline
- Flagged memory appears in owner review queue and can be resolved
