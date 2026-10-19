# Phase 3 · Step 2 — Group B: Event Grid

**Group B — Event Grid (`infra/modules/eventgrid.bicep`, new).** Custom topic
for the app's domain events, with event subscriptions routing to Functions
(stubs) and filters. No Service Bus changes, no Functions code.

## Events (from `docs/EVENTS.md` — central catalog; `docs/PLAN.md` §3 is source of truth)

Custom events: `checkin.due`, `voice.received`, `memory.archived`,
`memory.recorded`, `memory.flagged`, `alias.requested`, `alias.updated`.

## Decisions to record

- **Topic model**: custom topic (`Microsoft.EventGrid/topics`) vs system topic
  vs partner topic. Custom topic is right for app-emitted events.
- **Subscriptions**: one per consumer (e.g. `memory-recorded-to-sb` fans into
  Service Bus topic; `memory-flagged-to-review` to a Function). Use filters
  (`includedEventTypes`, `subjectBeginsWith`, advanced filters) to avoid
  delivering irrelevant events.
- **Retry policy**: `maxDeliveryAttempts` + `eventTimeToLiveInMinutes`; dead-letter
  to a storage container or Service Bus queue for failed deliveries.
- **Endpoint**: each subscription points at a Function (HTTP trigger) or Service
  Bus; for now point at placeholder endpoints and re-point in step 5.

## Stub shape

```bicep
// infra/modules/eventgrid.bicep — stub
resource topic 'Microsoft.EventGrid/topics@2024-06-01-preview' = {
  name: 'evg-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
}
```

## Verify

- [ ] Custom topic exists; endpoint + keys (key in Key Vault or use managed
      identity webhook validation).
- [ ] At least one event subscription with an `includedEventTypes` filter shown.
- [ ] Publish a test event by hand and confirm delivery attempt in metrics
      (even if the endpoint is a stub that returns 200).
- [ ] Module exports `topicEndpoint` / `topicName`.
