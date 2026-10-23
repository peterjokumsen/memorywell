# Phase 3 · Step 4 — Group D: Service Bus triggers

**Group D — Service Bus triggers (`functions/sb_transcription/`,
`functions/sb_guardian/`).** Two Service Bus-triggered stubs plus the DLQ path and
the identity wiring that lets them receive from the namespace. No transcription
(STT) or Guardian scoring logic.

## Triggers

| Function           | Entity                                                   | Connection             |
| ------------------ | -------------------------------------------------------- | ---------------------- |
| `sb_transcription` | queue `transcription`                                    | `ServiceBusConnection` |
| `sb_guardian`      | topic `memory.recorded` → subscription `guardian-review` | `ServiceBusConnection` |

Both entities already exist from step 1 (`infra/modules/servicebus.bicep`, which
is Standard because topics need it). Event inventory (emitter/consumer/purpose):
[`docs/EVENTS.md`](../EVENTS.md).

## Stub shapes

Python v2 model, one blueprint per function module, the same shape as
`timer_cadence`. Returning from the trigger **completes** the message; raising
abandons it and increments the delivery count.

```python
# functions/sb_transcription/__init__.py — stub
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.service_bus_queue_trigger(
    arg_name="message",
    queue_name="transcription",
    connection="ServiceBusConnection",
)
def sb_transcription(message: func.ServiceBusMessage) -> None:
    body = message.get_body().decode("utf-8", errors="replace")
    logging.info("transcription job received: %s", body)
    if body.strip() == "fail":
        raise RuntimeError("forced failure: exercise the dead-letter path")
```

```python
# functions/sb_guardian/__init__.py — stub
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.service_bus_topic_trigger(
    arg_name="message",
    topic_name="memory.recorded",
    subscription_name="guardian-review",
    connection="ServiceBusConnection",
)
def sb_guardian(message: func.ServiceBusMessage) -> None:
    body = message.get_body().decode("utf-8", errors="replace")
    logging.info("guardian review received: %s", body)
```

Register both blueprints in `functions/function_app.py`, next to the existing
two:

```python
from sb_guardian import bp as sb_guardian_bp
from sb_transcription import bp as sb_transcription_bp

app.register_blueprint(sb_guardian_bp)
app.register_blueprint(sb_transcription_bp)
```

The `fail` body is the deliberate DLQ switch for this phase: it needs no extra
app setting or redeploy, and it is easy to type into Service Bus Explorer.
Remove it when the real processing lands.

## Identity, not a connection string

The Service Bus extension supports identity-based connections (extension 5.x,
which the `[4.*, 5.0.0)` bundle already carries). Instead of a namespace SAS
string, set:

```plaintext
ServiceBusConnection__fullyQualifiedNamespace = <namespace>.servicebus.windows.net
ServiceBusConnection__credential               = managedidentity
ServiceBusConnection__clientId                 = <app identity client ID>
```

- `__clientId` is what selects the user-assigned identity; without it the
  extension tries a system-assigned identity the app doesn't have.
- Local runs: create `functions/local.settings.json` (already gitignored) with
  **only** `ServiceBusConnection__fullyQualifiedNamespace`, then `az login`. With
  no `__credential` setting the extension uses `DefaultAzureCredential`, so your
  CLI login is used. Never add `__credential=managedidentity` locally.
- Your developer principal needs `Azure Service Bus Data Receiver` on the
  entities you test against (see the grant below; assign it to yourself once).

## Infra changes

`infra/modules/servicebus.bicep` — take `identityPrincipalId string` (same
pattern as `cosmos.bicep`) and grant **Azure Service Bus Data Receiver**
(`4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0`) at the narrowest scopes:

```bicep
param identityPrincipalId string = ''

resource guardianTopic 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' existing = {
  parent: ns
  name: 'memory.recorded'
}

resource guardianReviewSub 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2024-01-01' existing = {
  parent: guardianTopic
  name: guardianSub
}

var serviceBusReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

resource queueReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: queue
  name: guid(queue.id, identityPrincipalId, serviceBusReceiverRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      serviceBusReceiverRoleId
    )
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// The same block again with `scope: guardianReviewSub` for the topic trigger.
// Both need `dependsOn: subs` — the subscriptions are created by the nested
// module, and an `existing` reference alone carries no ordering.
```

`functions.bicep` — add two params, then append the three settings above to
`appSettings`:

```bicep
param serviceBusNamespace string
param identityClientId string = ''
```

`platform.bicep` — pass `identityPrincipalId` into the Service Bus module and
the namespace + identity client ID into the Functions module:

```bicep
module serviceBus 'servicebus.bicep' = if (!databaseOnly) {
  params: {
    // existing params…
    identityPrincipalId: identityPrincipalId
  }
}

module functions 'functions.bicep' = if (!databaseOnly) {
  params: {
    // existing params…
    serviceBusNamespace: serviceBus.outputs.namespaceName
    identityClientId: identity.outputs.clientId
  }
}
```

Referencing `serviceBus.outputs` is also what orders the two modules.

Note on scaling: the extension queries the namespace's runtime properties to get
exact message counts. `Azure Service Bus Data Receiver` at entity scope covers
receive but not that read, so the extension silently falls back to peek-based
estimation. That is fine here — don't widen to namespace-scoped Data Owner just
for scale counts.

## DLQ path

Already configured in step 1: `maxDeliveryCount: 10` and
`deadLetteringOnMessageExpiration: true` on the queue. A raise in the stub
abandons the message; after ten failed deliveries it moves to the queue's
dead-letter sub-queue.

Azure CLI 2.91 has **no** `az servicebus queue message` commands, so resubmit
through the portal's Service Bus Explorer:

1. Namespace → Queues → `transcription` → Service Bus Explorer → **Send** a
   message whose body is exactly `fail`. It is delivered ten times, then shows
   under **Dead-letter**.
2. Open the dead-lettered message, change the body to `recovered`, and
   **Resubmit**. The stub logs it and the queue returns to zero.
3. Same drill for the topic: publish to `memory.recorded` and read the
   `guardian-review` subscription's dead-letter queue if you make the guardian
   stub fail too.

A scripted resubmit helper (SDK + `DefaultAzureCredential`) and the DLQ-depth
alert are Phase 7 work; this step only needs the manual path to be understood
and exercised. Leave a one-line note in the step doc once it works.

## Verify

- [ ] `func start` indexes four functions: `event_logger`, `timer_cadence`,
      `sb_transcription`, `sb_guardian`.
- [ ] `az bicep build --file infra/main.bicep` succeeds.
- [ ] Deployment grants the identity `Azure Service Bus Data Receiver` on the
      `transcription` queue and on the `guardian-review` subscription
      (`az role assignment list --scope <entity-id>`).
- [ ] The deployed app shows `ServiceBusConnection__*` settings and no SAS
      connection string.
- [ ] Send a message to `transcription` (portal or `az servicebus` is not
      available for messages — use Service Bus Explorer); the stub logs it and
      the queue depth returns to 0.
- [ ] Send the `fail` body; delivery count climbs to 10 and the message appears
      in the DLQ; edit the body, resubmit, and the queue drains.
- [ ] Publish `memory.recorded` to the topic; the `guardian-review` stub logs it
      and the subscription depth returns to 0.
- [ ] `az functionapp show` still reports `Running` after the change.
- [ ] `git status --short` shows no `local.settings.json` and no secrets.

## Troubleshooting

- **Function never appears after deploy** — the blueprint isn't registered in
  `function_app.py`; a trigger module that isn't imported never reaches the
  host's route table.
- **`cannot find value named 'ServiceBusConnection'`** — the setting prefix must
  match `connection="ServiceBusConnection"` exactly, including case.
- **401/403 from the namespace** — role assignment hasn't propagated (up to
  ~5 min), `__clientId` is the object ID instead of the client ID, or the
  identity was granted at the wrong scope.
- **Local run can't connect** — no `az login`, or the developer principal lacks
  Data Receiver on the entity; do not add `__credential=managedidentity` locally.
- **Message redelivered forever** — the stub raises on every delivery. Confirm
  the body and the `fail` check; the DLQ is the expected outcome, not a bug.
- **DLQ message keeps failing after resubmit** — resubmitting preserves the
  body; edit it to something the stub accepts before resubmitting.
