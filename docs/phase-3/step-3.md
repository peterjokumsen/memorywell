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
# functions/timer_cadence/__init__.py — stub (Python v2 model)
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.timer_trigger(schedule="0 0 8 * * *", arg_name="timer", run_on_startup=False)
def timer_cadence(timer: func.TimerRequest) -> None:
    logging.info("cadence sweep tick: past_due=%s", timer.past_due)
```

Register it in `functions/function_app.py` (`from timer_cadence import bp as
timer_cadence_bp` + `app.register_blueprint(timer_cadence_bp)`). A `def main`
without the blueprint is the v1 signature: the host indexes the v2 model from
`function_app.py` only, so the trigger silently never appears.

## Infra

`functions.bicep`: reuses the environment storage account for
`AzureWebJobsStorage` (one LRS account, not two), consumption plan
(`Y1`/Dynamic), Function App (Python 3.11, Linux), app settings
`FUNCTIONS_EXTENSION_VERSION=~4` + `FUNCTIONS_WORKER_RUNTIME=python`. Later
steps add Service Bus / Cosmos settings once their triggers exist.

The logger previously ran as a Container App (`ca-<base>-<env>-logger`).
Incremental Bicep deployments do not delete resources that left the template,
so remove that app once the Function App answers:

```bash
az containerapp delete -n "ca-${BASE_NAME}-${ENVIRONMENT}-logger" -g "$RG_NAME" --yes
```

## Verify

- [ ] `func start` (local, if Functions Core Tools installed) runs without
      import errors; timer trigger registers.
- [ ] `az functionapp show` → state `Running`; runtime `python`, version `3.11`.
- [ ] First timer invocation appears in logs (wait for schedule or run manually
      via portal "Run").
- [ ] No secrets in `functions/` or committed config.
