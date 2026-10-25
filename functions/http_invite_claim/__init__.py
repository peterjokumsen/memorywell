"""Magic-link invite claim stub.

``POST /api/invites/claim?token=…`` is the target of the web invite link. The
endpoint is anonymous by necessity: a browser following a magic link cannot
supply a function key.

The stub only checks that a token is present. Real claim logic — single-use
enforcement, expiry, and writing household membership — lands in Phase 5/8.

Registered as a blueprint in ``function_app.py``: a trigger module that is not
registered there never reaches the host's route table.

The Event Grid validation handshake is **not** here; it stays on ``/api/log``
(``functions/event_logger``).
"""

import json
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.route(route="invites/claim", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def http_invite_claim(req: func.HttpRequest) -> func.HttpResponse:
    token = (req.params.get("token") or "").strip()
    if not token:
        return func.HttpResponse("Missing token", status_code=400)

    # Never log the token itself: a magic link is a credential.
    logging.info("invite claim stub: token_len=%d", len(token))
    return func.HttpResponse(
        json.dumps({"status": "stub", "claimed": False}),
        status_code=200,
        mimetype="application/json",
    )
