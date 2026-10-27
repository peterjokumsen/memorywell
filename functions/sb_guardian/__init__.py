import json
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
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        logging.warning("invalid guardian payload")
        return
    logging.info("guardian scored memory %s", payload.get("memory_id"))
