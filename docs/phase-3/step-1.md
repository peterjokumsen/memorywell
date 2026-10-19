# Phase 3 · Step 1 — Group A: Service Bus

**Group A — Service Bus (`infra/modules/servicebus.bicep`, new).** Namespace
(Basic SKU, cheapest), one queue for voice-note transcription jobs, one topic
with fan-out subscriptions, and dead-letter handling. No Event Grid, no
Functions, no secrets wiring beyond what already exists.

## Topology (decide and record)

- **Queue**: `transcription` (as built; earlier drafts said `transcription-jobs`)
  — one message per voice note; consumed by the transcription worker (Phase 6).
  Use a queue (not a topic) because there is exactly one consumer and
  ordering/lock semantics matter.
- **Topic**: `memory-events` (or `memory.recorded`-style name; pick one and
  document it) with subscriptions:
  - `embedding-sub` — Cosmos change feed complement / embedding refresh.
  - `digest-sub` — digest generation (Phase 8).
  - `guardian-sub` — Guardian reviewer (Phase 4c).
- **Additional topics or filters** for `alias.requested`, `alias.updated`,
  `memory.flagged` — either as separate topics or as filtered subscriptions on
  the same topic using SQL/Correlation filters. Record the choice and why.
- **Dead-letter**: enable DLQ on every queue/subscription; set
  `maxDeliveryCount` (e.g. 10) and a lock duration (e.g. 30s). No
  retry-forever.

Naming decision: topic to have `{domain}.{event}` and subscriptions to be based on purpose (`memory-writer`, `memory-digest`, `guardian-review`)

Resolved as built: one topic per event — `memory.recorded`, `memory.flagged`,
`alias.requested`, `alias.updated` — each with purpose-named subscriptions;
queue `transcription`. Full emitter/consumer/purpose catalog: [`docs/EVENTS.md`](../EVENTS.md).

## Stub shape (write it yourself, keep it small)

```bicep
// infra/modules/servicebus.bicep — stub
resource ns 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sb-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  sku: { name: 'Basic' }
}
```

Basic SKU has no topics? Actually Basic supports queues only; topics require
Standard. **Correction**: Service Bus Basic tier supports queues only. If you
need topics + subscriptions (fan-out), use **Standard** SKU. Record the cost
trade-off and the SKU you chose. (This is the kind of gotcha to hit and
document.)

> Chosen `Standard` SKU to use topics

## Verify

- [x] `az servicebus namespace show` → state `Active`, SKU as chosen.
- [x] Queue + topic + ≥3 subscriptions listed; each has DLQ enabled.
- [x] Publish a test message by hand (portal or `az servicebus queue message send`)
      and confirm it appears; delete it after.
- [x] Module tagged; exports `namespaceName` / `queueName` / `topicName` for
      wiring in step 6.
