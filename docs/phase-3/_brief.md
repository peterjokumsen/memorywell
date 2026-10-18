# Phase 3 Brief — Messaging

> Status: not started (2026-10-18). Phase 2 merged (`2ee70f7`, PR #19).
> Branch: `phase-3` (from `origin/main`). Human builds by hand.
> Agent unblocks only.
>
> Layout: one `step-x.md` per ordered step in this directory; each step file
> carries its own instructions, stub shapes/notes, and verification checks.

## 1. Goal

Provision the messaging backbone and the Function App that will host the
event-driven triggers, with **stubs only** for the trigger handlers. No agent
logic, no API data clients, no frontend — those are Phases 4a–5. Phase 3 proves
that events flow: Service Bus messages round-trip, Event Grid delivers, Function
triggers fire, and the DLQ stays empty on the happy path.

Deploys, each as its own group (one step per group, no mixing):

- **Group A — Service Bus**: namespace, queue (transcription jobs), topic +
  subscriptions (`memory.recorded` fan-out: embedding / digest / guardian;
  `alias.requested`, `alias.updated`, `memory.flagged`), dead-letter handling.
- **Group B — Event Grid**: custom topic (or system topic) for the custom
  events (`checkin.due`, `voice.received`, `memory.archived`, `memory.recorded`,
  `memory.flagged`, `alias.requested`, `alias.updated`) with filters, retry
  policies, and routing to Functions.
- **Group C — Functions app scaffold + timer trigger**: daily cadence sweep per
  (chronicle, contributor) (stub).
- **Group D — Service Bus triggers**: transcription worker + Guardian reviewer
  (stubs), plus DLQ resubmit/monitor path.
- **Group E — Cosmos change feed + HTTP triggers**: embedding generation on
  change feed (stub), webhook + magic-link invite claim (stub).
- **Group F — Identity, secrets, app settings wiring + deploy + hygiene**.

Out of scope: agent implementations (Prompter/Curator/Guardian logic), RAG
retrieval, frontend, voice/photo pipeline beyond the transcription queue stub,
OpenTelemetry wiring (Phase 7). No pre-building later phases.

## 2. AI-200 concepts practised

- Connect/consume: **Service Bus** queues, **topics + subscriptions** with
  fan-out, **dead-letter queues** with a resubmit/monitor path.
- Connect/consume: **Event Grid** custom events with **filters**, retry policies,
  and routing to Functions.
- Connect/consume: **Azure Functions** triggers and bindings — timer, Service Bus,
  Cosmos change feed, HTTP — on the consumption plan.
- Secure: managed identity for the Function App to Service Bus / Cosmos / Key
  Vault; connection settings via app settings + Key Vault references.
- Containerized solutions are untouched this phase (API container stays as-is).

## 3. Prerequisites

- Phase 2 merged; clean `git status` on `phase-3`.
- `az login` works; `.env` has `BASE_NAME`/`ENVIRONMENT`/`LOCATION`
  (`westeurope`)/`SUBSCRIPTION_ID`.
- Read: `docs/PLAN.md` §§ Architecture §3, Build phases row 3, Verification;
  `AGENTS.md` §§ Domain invariants, Repo rules.

## 4. Ordered steps (human builds, one group per step)

| Step | File                   | Group                                                        |
| ---- | ---------------------- | ------------------------------------------------------------ |
| 1    | [step-1.md](step-1.md) | Group A — Service Bus (queue, topic, subs, DLQ)              |
| 2    | [step-2.md](step-2.md) | Group B — Event Grid (custom topic, filters, retries)        |
| 3    | [step-3.md](step-3.md) | Group C — Functions scaffold + timer trigger (cadence sweep) |
| 4    | [step-4.md](step-4.md) | Group D — Service Bus triggers (transcription, guardian)     |
| 5    | [step-5.md](step-5.md) | Group E — Change feed (embeddings) + HTTP invite claim       |
| 6    | [step-6.md](step-6.md) | Group F — Wiring + deploy + hygiene                          |

Do not start a step before the previous one verifies. No Phase 4 work starts
until the §6 review gate passes.

## 5. File outline (stubs, not implementations)

```plaintext
infra/modules/servicebus.bicep   # Group A: namespace + queue + topic + subs + DLQ
infra/modules/eventgrid.bicep    # Group B: custom topic + event subscriptions
infra/modules/functions.bicep    # Group C–E: Function App (consumption) + plan + storage
infra/modules/platform.bicep    # + servicebus/eventgrid/functions composition (edit only)
infra/modules/vault.bicep       # + Service Bus connection string? (prefer identity)
functions/host.json             # Functions host config
functions/requirements.txt      # azure-functions, azure-servicebus, azure-cosmos, ...
functions/function_app.py       # Python v2 model entry point, registers triggers
functions/timer_cadence/__init__.py
functions/sb_transcription/__init__.py
functions/sb_guardian/__init__.py
functions/cosmos_changefeed/__init__.py
functions/http_invite_claim/__init__.py
scripts/...                    # no new scripts expected; deploy.sh gains functions deploy
docs/phase-3/                  # this brief + one step-x.md per step
```

## 6. Review gate (demo before Phase 4)

Paste back into chat:

1. Service Bus namespace + queue + topic + subscription list; DLQ message count
   (0 on happy path).
2. Event Grid topic endpoint + at least one event subscription with a filter
   shown.
3. Function App URL + a successful timer/HTTP trigger invocation log.
4. A Service Bus message published by hand is consumed by the transcription
   stub and lands in the right subscription; Event Grid event delivered to a
   Function.
5. `git status --short` + `git log --oneline -5`.
6. One paragraph: queue vs topic choice, why DLQ + resubmit instead of
   retry-forever, and how you'd split the Function App if cold starts bite.

Agent sanity-checks the above, then issues the Phase 4a brief. No Phase 4 work
starts until the gate passes. Cost reminder: destroy resources between sessions
(`scripts/teardown.sh`); Phase 3 adds Service Bus Basic + Event Grid + Functions
consumption (near-zero when idle) + storage account.
