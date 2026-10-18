# Phase 2 · Step 3 — Group C: Redis

**Group C — Redis (`infra/modules/redis.bicep`, new).** Cheapest Basic SKU,
`westeurope`, TLS-only. No VNet/firewall rules in Phase 2 (dev-only public
endpoint; note prod hardening as a comment for Phase 8). Prove `PING` from
the seed script. Nothing else in this step.

## Verify

- [ ] Redis `PING` → `PONG` (from seed output or `redis-cli`).
