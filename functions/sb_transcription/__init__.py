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
