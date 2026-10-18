# Phase 3 · Step 3 — Group C: Functions scaffold + timer trigger

**Group C — Functions app (`functions/`, new) + `infra/modules/functions.bicep`.**
Consumption plan, Python 3.11, one timer trigger stub (daily cadence sweep).
No agent logic.

## Scaffold

```plaintext
functions/
  host.json
  requirements.txt
  function_app.py          # Python v2 model; registers triggers via decorators
  timer_cadence/
    __init__.py            # timer trigger stub
```

- `host.json`: extension bundle, logging, `extensions.serviceBus` prefetch
  settings (defaults fine for now).
- `requirements.txt`: `azure-functions`, `azure-identity`, `azure-cosmos`,
  `azure-servicebus` (pinned). Add OpenAI SDKs only when Phase 4 needs them.
- `function_app.py`: import each trigger module so decorators register.

## Timer trigger stub

Daily cadence sweep per (chronicle, contributor): weekly if 7d elapsed, monthly
if 30d elapsed, special-occasions only on calendar/milestone events, `none`
skips proactive prompts. **Stub only** — log "cadence sweep tick" and return.
Real filtering lands in Phase 4a.

```python
# functions/timer_cadence/__init__.py — stub
import logging
import azure.functions as func

def main(timer: func.TimerRequest) -> None:
    logging.info("cadence sweep tick: %s", timer.past_due)
```

## Infra

`functions.bicep`: storage account (Functions runtime requirement), consumption
plan (`Y1`/Dynamic), Function App (Python, Linux), app settings pointing at
Service Bus / Cosmos / Key Vault via managed identity or connection strings.

## Verify

- [ ] `func start` (local, if Functions Core Tools installed) runs without
      import errors; timer trigger registers.
- [ ] `az functionapp show` → state `Running`; runtime `python`, version `3.11`.
- [ ] First timer invocation appears in logs (wait for schedule or run manually
      via portal "Run").
- [ ] No secrets in `functions/` or committed config.
