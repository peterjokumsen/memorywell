import json
import logging

import azure.functions as func
from cosmos import _db, container, new_id, now

bp = func.Blueprint()


@bp.route(
    route="chronicles", methods=["GET", "POST", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS
)
def http_chronicles(req):
    db = _db()
    if req.method == "OPTIONS":
        return func.HttpResponse("", status_code=204, headers={"Access-Control-Allow-Origin": "*"})
    if db is None:
        return func.HttpResponse("Cosmos not configured", status_code=503)
    if req.method == "GET":
        hid = (req.params.get("householdId") or "").strip()
        if not hid:
            return func.HttpResponse("Missing householdId", status_code=400)
        q = "SELECT * FROM c WHERE c.householdId = @hid"
        items = list(
            container(db, "chronicles").query_items(q, parameters=[{"name": "@hid", "value": hid}])
        )
        return func.HttpResponse(
            json.dumps(items),
            status_code=200,
            mimetype="application/json",
            headers={"Access-Control-Allow-Origin": "*"},
        )
    body = req.get_json() if req.get_body() else {}
    name = (body.get("name") or "").strip()
    hid = (body.get("householdId") or "").strip()
    if not name or not hid:
        return func.HttpResponse("Missing name or householdId", status_code=400)
    doc = {"id": new_id(), "householdId": hid, "name": name, "createdAt": now()}
    container(db, "chronicles").upsert_item(doc)
    logging.info("created chronicle %s", doc["id"])
    return func.HttpResponse(
        json.dumps(doc),
        status_code=201,
        mimetype="application/json",
        headers={"Access-Control-Allow-Origin": "*"},
    )
