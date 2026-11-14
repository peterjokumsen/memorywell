import json
import logging

import azure.functions as func
from cosmos import _db, container, is_deleted, new_id, now


def _resp(data, status=200):
    return func.HttpResponse(
        json.dumps(data),
        status_code=status,
        mimetype="application/json",
        headers={"Access-Control-Allow-Origin": "*"},
    )


def _options():
    return func.HttpResponse("", status_code=204, headers={"Access-Control-Allow-Origin": "*"})


def make_blueprint(entity, pk_field, required_fields=None, defaults=None, partition_resolver=None):
    required_fields = required_fields or []
    defaults = defaults or {}
    bp = func.Blueprint()

    def _partition_value(doc_or_params):
        if partition_resolver:
            return partition_resolver(doc_or_params)
        if pk_field == "id":
            return doc_or_params.get("id") if isinstance(doc_or_params, dict) else doc_or_params
        # for household/chronicle partition fields
        if isinstance(doc_or_params, dict):
            return doc_or_params.get(pk_field)
        return doc_or_params.get(pk_field) if hasattr(doc_or_params, "get") else None

    @bp.function_name(f"{entity}_collection")
    @bp.route(route=entity, methods=["GET", "POST", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
    def collection(req):
        db = _db()
        if req.method == "OPTIONS":
            return _options()
        if db is None:
            return func.HttpResponse("Cosmos not configured", status_code=503)
        coll = container(db, entity)
        if req.method == "GET":
            include_deleted = req.params.get("includeDeleted") == "true"
            # build simple equality filters from query params matching known fields
            filters = []
            params = []
            for key in ("householdId", "chronicleId", "contributorId"):
                val = req.params.get(key)
                if val:
                    filters.append(f"c.{key} = @{key}")
                    params.append({"name": f"@{key}", "value": val})
            q = "SELECT * FROM c"
            if filters:
                q += " WHERE " + " AND ".join(filters)
            items = list(coll.query_items(q, parameters=params, enable_cross_partition_query=True))
            if not include_deleted:
                items = [x for x in items if not is_deleted(x)]
            return _resp(items)
        body = req.get_json() if req.get_body() else {}
        for f in required_fields:
            if (
                not (body.get(f) or "").strip()
                if isinstance(body.get(f), str)
                else body.get(f) is None
            ):
                return func.HttpResponse(f"Missing {f}", status_code=400)
        doc = {"id": new_id(), "createdAt": now()}
        doc.update(defaults)
        for k, v in body.items():
            if k not in ("id", "createdAt"):
                doc[k] = v
        if pk_field != "id" and pk_field not in doc:
            # allow pk from body already
            pass
        coll.upsert_item(doc)
        logging.info("created %s %s", entity, doc["id"])
        return _resp(doc, 201)

    @bp.function_name(f"{entity}_item")
    @bp.route(
        route=f"{entity}/{{item_id}}",
        methods=["GET", "PUT", "PATCH", "DELETE", "OPTIONS"],
        auth_level=func.AuthLevel.ANONYMOUS,
    )
    def item(req, item_id):
        id = item_id
        db = _db()
        if req.method == "OPTIONS":
            return _options()
        if db is None:
            return func.HttpResponse("Cosmos not configured", status_code=503)
        coll = container(db, entity)
        # resolve partition value
        if req.method == "GET":
            try:
                doc = coll.read_item(item=id, partition_key=_partition_for_read(coll, id, req))
            except Exception:
                # fallback cross-partition query
                docs = list(
                    coll.query_items(
                        "SELECT * FROM c WHERE c.id = @id",
                        parameters=[{"name": "@id", "value": id}],
                        enable_cross_partition_query=True,
                    )
                )
                if not docs:
                    return func.HttpResponse("Not found", status_code=404)
                doc = docs[0]
            if is_deleted(doc) and req.params.get("includeDeleted") != "true":
                return func.HttpResponse("Not found", status_code=404)
            return _resp(doc)
        if req.method == "DELETE":
            # find doc
            docs = list(
                coll.query_items(
                    "SELECT * FROM c WHERE c.id = @id",
                    parameters=[{"name": "@id", "value": id}],
                    enable_cross_partition_query=True,
                )
            )
            if not docs:
                return func.HttpResponse("Not found", status_code=404)
            d = docs[0]
            d["deletedAt"] = now()
            d["isDeleted"] = True
            coll.upsert_item(d)
            return func.HttpResponse(
                "", status_code=204, headers={"Access-Control-Allow-Origin": "*"}
            )
        body = req.get_json() if req.get_body() else {}
        docs = list(
            coll.query_items(
                "SELECT * FROM c WHERE c.id = @id",
                parameters=[{"name": "@id", "value": id}],
                enable_cross_partition_query=True,
            )
        )
        if not docs:
            return func.HttpResponse("Not found", status_code=404)
        d = docs[0]
        if req.method == "PUT":
            newdoc = {"id": id, "createdAt": d.get("createdAt", now())}
            newdoc.update({k: v for k, v in body.items() if k not in ("id", "createdAt")})
            # preserve partition field if not provided
            if pk_field != "id" and pk_field not in newdoc:
                newdoc[pk_field] = d.get(pk_field)
            coll.upsert_item(newdoc)
            return _resp(newdoc)
        # PATCH
        for k, v in body.items():
            if k not in ("id", "createdAt"):
                d[k] = v
        coll.upsert_item(d)
        return _resp(d)

    return bp


def _partition_for_read(coll, id, req):
    # Cosmos read_item requires partition key; try from query params
    for key in ("householdId", "chronicleId"):
        v = req.params.get(key)
        if v:
            return v
    return id
