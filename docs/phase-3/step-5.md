# Phase 3 · Step 5 — Group E: Change feed + HTTP triggers

**Group E — Cosmos change feed (`functions/cosmos_changefeed/`) and HTTP
(`functions/http_invite_claim/`).** Two stubs plus the lease container and the
identity wiring that lets the change-feed processor read `memories`. No
embedding generation, no membership writes.

## Change feed trigger

| Item            | Value                                      |
| --------------- | ------------------------------------------ |
| Database        | `memorywell` (`COSMOS_DATABASE`)           |
| Container       | `memories` (partition key `/chronicleId`)  |
| Lease container | `leases` (new, partition key `/id`)        |
| Connection      | `CosmosDBConnection` (identity, not a key) |

Python v2 keeps the legacy argument names on this decorator: `collection_name`
(not container) and `connection_string_setting` (the app-setting **prefix**).
The stub logs each changed document's `id` and `chronicleId`, then returns.

```python
# functions/cosmos_changefeed/__init__.py — stub
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.cosmos_db_trigger_v3(
    arg_name="documents",
    database_name="memorywell",
    collection_name="memories",
    connection_string_setting="CosmosDBConnection",
    lease_collection_name="leases",
    create_lease_collection_if_not_exists=True,
    start_from_beginning=False,
)
def cosmos_changefeed(documents: func.DocumentList) -> None:
    for document in documents:
        logging.info(
            "change feed: id=%s chronicleId=%s",
            document.get("id"),
            document.get("chronicleId"),
        )
```

`start_from_beginning=False` matters: with a fresh lease container the
processor starts at "now" instead of replaying every memory in the container. A
redeploy resumes from the checkpoint, not from the beginning.

The database name is a literal because the decorator is evaluated at import
time; keep it in sync with `COSMOS_DATABASE` (`memorywell` for every
environment — it is not suffixed with the env name).

## Lease container

Add it to `infra/modules/cosmos.bicep` rather than letting the extension create
it, so the container shape lives in IaC:

```bicep
var containers = [
  // …existing containers
  { name: 'leases', pk: '/id' } // change-feed processor leases; pk must be /id
]
```

`create_lease_collection_if_not_exists=True` stays as a fallback, but the Bicep
container is the source of truth. The environment identity already holds
**Cosmos DB Built-in Data Contributor at database scope** from step 2, which
covers both `memories` and `leases` — no new role assignment in this step.

## Identity wiring

The account has `disableLocalAuth: true`, so keys are not an option. Set the
connection prefix on the Function App:

```plaintext
CosmosDBConnection__accountEndpoint = https://cosmos-<base>-<env>.documents.azure.com:443/
CosmosDBConnection__credential      = managedidentity
CosmosDBConnection__clientId        = <app identity client ID>
```

Local runs: add **only** `CosmosDBConnection__accountEndpoint` to
`functions/local.settings.json` (no `__credential`), then `az login`. Your
developer principal already has the Cosmos data role via
`COSMOS_USER_OBJECT_ID` from Phase 2.

`container-apps` mode is the wrinkle: `cosmos.bicep` is skipped there but the
Function App still deploys for the Event Grid sink. So `platform.bicep` passes
`cosmos.?outputs.accountEndpoint ?? ''`, and `functions.bicep` adds the three
settings only when that value is non-empty:

```bicep
var cosmosAppSettings = empty(cosmosAccountEndpoint)
  ? []
  : [
      { name: 'CosmosDBConnection__accountEndpoint', value: cosmosAccountEndpoint }
      { name: 'CosmosDBConnection__credential', value: 'managedidentity' }
      { name: 'CosmosDBConnection__clientId', value: identityClientId }
    ]
```

Keep the existing settings in a `baseAppSettings` array and pass
`appSettings: concat(baseAppSettings, cosmosAppSettings)`.

## HTTP trigger

`POST /api/invites/claim` — the target of the magic link. It must be anonymous:
a browser following a link cannot supply a function key. Validate only that a
token is present; membership writes, single-use enforcement and expiry are
Phase 5/8.

```python
# functions/http_invite_claim/__init__.py — stub
import json
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.route(route="invites/claim", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def http_invite_claim(req: func.HttpRequest) -> func.HttpResponse:
    token = (req.params.get("token") or "").strip()
    if not token:
        return func.HttpResponse("Missing token", status_code=400)

    # Never log the token itself; a magic link is a credential.
    logging.info("invite claim stub: token_len=%d", len(token))
    return func.HttpResponse(
        json.dumps({"status": "stub", "claimed": False}),
        status_code=200,
        mimetype="application/json",
    )
```

The Event Grid validation handshake already lives on `/api/log`
(`functions/event_logger`, step 2). This step does **not** add a second webhook
endpoint — the earlier outline was wrong, and `docs/EVENTS.md` is corrected in
the same change.

Register both blueprints in `functions/function_app.py`:

```python
from cosmos_changefeed import bp as cosmos_changefeed_bp
from http_invite_claim import bp as http_invite_claim_bp

app.register_blueprint(cosmos_changefeed_bp)
app.register_blueprint(http_invite_claim_bp)
```

## Infra changes

- `infra/modules/cosmos.bicep` — add the `leases` container.
- `infra/modules/functions.bicep` — `param cosmosAccountEndpoint string = ''`,
  the conditional settings above.
- `infra/modules/platform.bicep` — pass
  `cosmosAccountEndpoint: cosmos.?outputs.accountEndpoint ?? ''` into the
  `functions` module. No `main.bicep` change: it already passes
  `identityClientId`.
- `functions/local.settings.json.template` — add the
  `CosmosDBConnection__accountEndpoint` placeholder next to the Service Bus one.

## Verify

- [ ] `func start` indexes six functions: `event_logger`, `timer_cadence`,
      `sb_transcription`, `sb_guardian`, `cosmos_changefeed`,
      `http_invite_claim`.
- [ ] `az bicep build --file infra/main.bicep` succeeds.
- [ ] `leases` exists with partition key `/id`
      (`az cosmosdb sql container show … --query "resource.partitionKey"`).
- [ ] The deployed app shows `CosmosDBConnection__*` and no Cosmos key.
- [ ] Insert a document into `memories` (Data Explorer → New Item) with `id` and
      `chronicleId` set; `func start` logs `change feed: id=…` within a few
      seconds.
- [ ] Restart the app, insert a second document; only the new one is logged (no
      replay of the container).
- [ ] `curl -X POST http://localhost:7071/api/invites/claim` → 400;
      `?token=abc` → 200 with `{"status":"stub","claimed":false}`.
- [ ] Regression: a `SubscriptionValidationEvent` posted to `/api/log` still
      returns `validationResponse`.
- [ ] `git status --short` shows no `local.settings.json` and no secrets.

Deployed log checks are local-only for now: the app still has no
`APPLICATIONINSIGHTS_CONNECTION_STRING`, and built-in log streaming is not
supported on Linux Consumption. Behaviour on the deployed app is visible only
through data-plane state (new documents processed, lease checkpoints advancing).

## Troubleshooting

- **Trigger indexes but no documents arrive** — the lease container is missing
  or has the wrong partition key, or a deployed instance is competing for the
  same leases. Stop the deployed app while testing locally, or set a distinct
  `lease_collection_prefix` for the local run.
- **403 / `Forbidden … items/upsert` on leases** — the identity has the Reader
  role instead of Contributor at database scope, or the grant has not propagated
  (~5 min).
- **Everything replays after a deploy** — `start_from_beginning=True`, or the
  lease container was deleted so the processor started over.
- **404 on `/api/invites/claim`** — blueprint not registered in
  `function_app.py`; the route only exists once the host indexes it.
- **`cannot find value named 'CosmosDBConnection'`** — prefix mismatch with
  `connection_string_setting`, or the settings were skipped because
  `cosmosAccountEndpoint` was empty.
