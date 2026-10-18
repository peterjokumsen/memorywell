# Phase 3 · Step 5 — Group E: Change feed + HTTP triggers

**Group E — Cosmos change feed trigger (`functions/cosmos_changefeed/`) and
HTTP trigger (`functions/http_invite_claim/`).** Stubs only.

## Change feed trigger

- Trigger on the `memories` container change feed; lease container
  `leases` (create it in Cosmos, or let the extension create it).
- Stub: log the changed document ids. Real embedding generation lands in
  Phase 4b.
- Configure `startFromBeginning` carefully (false by default) so redeploys
  don't replay the whole container.

## HTTP trigger

- `POST /api/invites/claim` (or similar): magic-link invite claim. Stub
  validates a token param and returns 200/400. Real claim logic (household
  membership write) lands in Phase 5/8.
- Webhook endpoint for Event Grid validation (return `validationCode`).

## Verify

- [ ] Insert a memory doc in Cosmos; the change feed stub logs its id within
      the lease window.
- [ ] `curl -X POST <function-url>/api/invites/claim` returns the stub
      response.
- [ ] Event Grid subscription endpoint passes validation handshake.
