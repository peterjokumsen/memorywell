import json
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
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        logging.warning("invalid transcription payload")
        return
    memory_id = payload.get("memory_id")
    blob_url = payload.get("blob_url")
    logging.info("transcribing memory %s from %s", memory_id, blob_url)
    if body.strip() == "fail":
        raise RuntimeError("forced failure: exercise the dead-letter path")
