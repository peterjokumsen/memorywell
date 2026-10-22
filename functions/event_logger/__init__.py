"""Event Grid event logger.

Registered as a blueprint in ``function_app.py``: without that registration the
route never reaches the host's route table and every call 404s.
"""

import json
import logging

import azure.functions as func

bp = func.Blueprint()


@bp.route(route="log", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def event_logger(req: func.HttpRequest) -> func.HttpResponse:
    """
    Generic Event Grid event logger.
    Accepts Event Grid events (single or array) and logs them.
    """
    try:
        body = req.get_body()
        if not body:
            return func.HttpResponse("Empty body", status_code=400)

        events = json.loads(body)

        # Event Grid sends either a single event object or an array
        if isinstance(events, dict):
            events = [events]

        for event in events:
            # Handle Event Grid validation handshake
            if event.get("eventType") == "Microsoft.EventGrid.SubscriptionValidationEvent":
                validation_code = event.get("data", {}).get("validationCode")
                if validation_code:
                    logging.info(f"Event Grid validation request received: {validation_code}")
                    return func.HttpResponse(
                        json.dumps({"validationResponse": validation_code}),
                        status_code=200,
                        mimetype="application/json",
                    )

            # Log the event
            event_type = event.get("eventType", "unknown")
            subject = event.get("subject", "")
            event_id = event.get("id", "")
            data = event.get("data", {})

            logging.info(
                "Event received | type=%s | subject=%s | id=%s | data=%s",
                event_type,
                subject,
                event_id,
                json.dumps(data, default=str),
            )

        return func.HttpResponse("OK", status_code=200)

    except json.JSONDecodeError as e:
        logging.error("Invalid JSON: %s", e)
        return func.HttpResponse("Invalid JSON", status_code=400)
    except Exception as e:
        logging.exception("Error processing event: %s", e)
        return func.HttpResponse("Internal error", status_code=500)
