"""Python v2 programming model entry point for the MemoryWell Functions app.

The Functions host indexes the v2 model from this file only. A FunctionApp (or
a Blueprint) defined in any other file is invisible to the route table, which
is why a trigger module that is not registered here returns 404 no matter how
correct its code is.

Every trigger module therefore exposes a ``bp = func.Blueprint()`` and is
registered below.

Hosting: a Linux consumption-plan Function App (infra/modules/functions.bicep).
It does have the usual function-key store (AzureWebJobsStorage), but the log
sink still defaults to ANONYMOUS: an Event Grid webhook destination cannot send
a function key, and the sink exists to receive those deliveries. Authenticated
HTTP endpoints added in later steps set their own level and key/identity check.
"""

import azure.functions as func
from event_logger import bp as event_logger_bp
from timer_cadence import bp as timer_cadence_bp

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

app.register_blueprint(event_logger_bp)
app.register_blueprint(timer_cadence_bp)
