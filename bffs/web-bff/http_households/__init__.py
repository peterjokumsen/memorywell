import json
import logging

import azure.functions as func
from cosmos import _db, container, new_id, now

bp = func.Blueprint()


@bp.route(
    route="households", methods=["GET", "POST", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS
)
def http_households(req):
    db = _db()
    if req.method == "OPTIONS":
        return func.HttpResponse("", status_code=204, headers={"Access-Control-Allow-Origin": "*"})
    if db is None:
        return func.HttpResponse("Cosmos not configured", status_code=503)
    if req.method == "GET":
        items = list(
            container(db, "households").query_items(
                "SELECT * FROM c", enable_cross_partition_query=True
            )
        )
        return func.HttpResponse(
            json.dumps(items),
            status_code=200,
            mimetype="application/json",
            headers={"Access-Control-Allow-Origin": "*"},
        )
    body = req.get_json() if req.get_body() else {}
    name = (body.get("name") or "").strip()
    if not name:
        return func.HttpResponse("Missing name", status_code=400)
    doc = {"id": new_id(), "name": name, "createdAt": now()}
    container(db, "households").upsert_item(doc)
    logging.info("created household %s", doc["id"])
    return func.HttpResponse(
        json.dumps(doc),
        status_code=201,
        mimetype="application/json",
        headers={"Access-Control-Allow-Origin": "*"},
    )
