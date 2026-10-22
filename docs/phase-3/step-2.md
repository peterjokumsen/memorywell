# Phase 3 · Step 2 — Group B: Event Grid

**Group B — Event Grid (`infra/modules/eventgrid.bicep`, new).** Event Grid
**domain** (`evg-<base>-<env>`) for the app's domain events, with event
subscriptions routing to Functions (stubs) and filters. No Service Bus changes,
no Functions code.

## Events (from `docs/EVENTS.md` — central catalog; `docs/PLAN.md` §3 is source of truth)

Custom events: `checkin.due`, `voice.received`, `memory.archived`,
`memory.recorded`, `memory.flagged`, `alias.requested`, `alias.updated`.

## Decisions to record

- **Topic model (decided)**: an Event Grid **domain**
  (`Microsoft.EventGrid/domains`), not a single custom topic. Chosen for the
  namespace shape — one publishing endpoint for many related topics, per-topic
  RBAC/partitioning available later, and room to experiment with
  per-chronicle/per-tenant topics without adding a new top-level resource. Today
  it behaves like one topic: six **domain-scope** subscriptions filter by
  `includedEventTypes`, and no domain topics are materialized.
  - Publishing names the target topic in the event: `"topic": "memory.recorded"`
    (Event Grid schema) or `source` (CloudEvents). On a custom topic that field
    is the topic's resource ID instead.
  - Domain topics are auto-managed when a subscription is created at domain-topic
    scope (`autoCreateTopicWithFirstSubscription`), which is the path if we later
    partition by chronicle/tenant. Until then, publishing to a new topic name
    works without creating the `domains/topics` resource.
  - Limits: 100 domains per subscription, 100k topics per domain, 50 domain-scope
    subscriptions (six used). Pricing is the same per-operation model as custom
    topics.
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
// infra/modules/eventgrid.bicep — as built
resource domain 'Microsoft.EventGrid/domains@2025-02-15' = {
  name: 'evg-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  properties: {
    autoCreateTopicWithFirstSubscription: false
    autoDeleteTopicWithLastSubscription: false
  }
}

// Domain-scope subscriptions receive events for every topic in the domain, so
// the filter (not the topic) is what selects a consumer. Domain-topic-scoped
// subscriptions are the alternative once we partition by tenant/chronicle.
resource subscription 'Microsoft.EventGrid/domains/eventSubscriptions@2025-02-15' = [
  for sub in enabledSubs: {
    parent: domain
    name: sub.name
    properties: {
      destination: sub.destination
      filter: sub.filter
      retryPolicy: defaultRetryPolicy
    }
  }
]
```

## Verify

- [ ] Domain exists; endpoint + keys (key in Key Vault or use managed identity
      webhook validation).
- [ ] At least one domain-scope event subscription with an `includedEventTypes`
      filter shown.
- [ ] Publish a test event by hand (`"topic": "<event name>"`) and confirm
      delivery in metrics (`PublishSuccessCount`, `DeliverySuccessCount`) and in
      the consumer's log.
- [ ] Module exports `domainName` / `domainEndpoint` / `topicNames`.
