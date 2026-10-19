# Phase 3 · Step 4 — Group D: Service Bus triggers

**Group D — Service Bus triggers (`functions/sb_transcription/`,
`functions/sb_guardian/`).** Two Service Bus-triggered functions (stubs) plus the
DLQ resubmit/monitor path. No transcription/STT or Guardian scoring logic.

## Triggers

- `sb_transcription`: trigger on `transcription` queue (as built; earlier drafts
  said `transcription-jobs`). Stub logs the
  message body and completes. Real STT + transcript write lands in Phase 6.
- `sb_guardian`: trigger on the `guardian-review` subscription of the
  `memory.recorded` topic (as built; earlier drafts said `guardian-sub` on
  `memory-events`). Stub logs and completes. Real scoring lands in Phase 4c.

Event inventory (emitter/consumer/purpose): [`docs/EVENTS.md`](../EVENTS.md).

Both must use the Functions Service Bus extension binding; configure the
connection via app setting (managed identity preferred — `azure-identity` +
`ServiceBusClient` with `DefaultAzureCredential`, or the extension's identity
binding).

## DLQ handling

- Failed processing (raise) → message lands in DLQ after `maxDeliveryCount`.
- Provide a resubmit path: either a small script or a Function that reads DLQ
  messages and re-sends them. At minimum, document the `az servicebus queue
message peek` / resubmit commands.
- Add a monitor/alert for DLQ depth (wired fully in Phase 7; stub the
  threshold in App Config later).

## Verify

- [ ] Send a message to `transcription`; the `sb_transcription` stub
      logs it and completes; queue depth returns to 0.
- [ ] Force a failure (raise in stub behind a flag) and confirm the message
      reaches the DLQ after max deliveries; then resubmit and confirm it drains.
- [ ] `guardian-review` receives a published `memory.recorded` event and the
      stub logs it.
