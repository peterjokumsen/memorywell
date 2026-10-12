# Phase 2 · Step 4 — Group D: Secrets wiring

**Group D — Secrets wiring (edit `infra/modules/platform.bicep` +
`infra/modules/vault.bicep` only).** Store three secrets in the existing
Key Vault: Cosmos connection string (or endpoint + key pair), Postgres
connection string, Redis connection string. Grant the existing API
user-assigned identity `Key Vault Secrets User` (reuse the pattern in
`vault.bicep`) — no new identity. Bicep must not emit secrets in outputs.
This step touches only secret plumbing.

## Verify

- [ ] Three secrets present in `kv-<base>-<env>`; Bicep outputs contain no
      secret values; API identity holds `Key Vault Secrets User`.
