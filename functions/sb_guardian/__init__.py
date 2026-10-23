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
