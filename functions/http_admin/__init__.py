"""Administration HTTP endpoints backed by Cosmos DB."""

import json
import logging
import os
import uuid

import azure.functions as func
from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import ManagedIdentityCredential

bp = func.Blueprint()


def _principal(req):
    import base64
    import json

    raw = req.headers.get("X-MS-CLIENT-PRINCIPAL")
    if not raw:
        return None
    try:
        decoded = base64.b64decode(raw)
        return json.loads(decoded)
    except Exception:
        return None


def _is_admin(req):
    p = _principal(req)
    if p is None:
        return True  # dev/local fallback
    roles = p.get("userRoles") or []
    claims = p.get("claims", [])
    role_claims = [c.get("val") for c in claims if c.get("typ") == "roles"]
    all_roles = set(roles) | set(role_claims)
    return bool(all_roles & {"Owner", "Co-Owner", "admin"})


CONTAINER_PKS = {
    "households": "/id",
    "chronicles": "/householdId",
    "contributors": "/householdId",
}


def _db():
    endpoint = os.environ.get("COSMOS_ENDPOINT") or os.environ.get(
        "CosmosDBConnection__accountEndpoint"
    )
    database = os.environ.get("CosmosDB_name") or "memorywell"
    if not endpoint:
        return None
    client_id = os.environ.get("CosmosDBConnection__clientId")
    credential = (
        ManagedIdentityCredential(client_id=client_id) if client_id else ManagedIdentityCredential()
    )
    client = CosmosClient(endpoint, credential=credential)
    return client.get_database_client(database)


def _container(db, name):
    pk = CONTAINER_PKS[name]
    if name not in {c["id"] for c in db.list_containers()}:
        db.create_container_if_not_exists(id=name, partition_key=PartitionKey(path=pk))
    return db.get_container_client(name)


def _now():
    import datetime

    return datetime.datetime.now(datetime.UTC).isoformat()


def _fail(msg, code=400):
    return func.HttpResponse(msg, status_code=code)


@bp.route(route="households", methods=["GET", "POST"], auth_level=func.AuthLevel.ANONYMOUS)
def http_households(req: func.HttpRequest) -> func.HttpResponse:
    db = _db()
    if db is None:
        return _fail("Cosmos not configured", 503)
    if req.method == "GET":
        q = "SELECT * FROM c"
        items = list(_container(db, "households").query_items(q, enable_cross_partition_query=True))
        return func.HttpResponse(json.dumps(items), status_code=200, mimetype="application/json")
    try:
        body = req.get_json()
    except ValueError:
        body = {}
    if not _is_admin(req):
        return _fail("Forbidden", 403)
    name = (body.get("name") or "").strip()
    if not name:
        return _fail("Missing name")
    doc = {"id": str(uuid.uuid4()), "name": name, "createdAt": _now()}
    _container(db, "households").upsert_item(doc)
    logging.info("admin: created household %s", doc["id"])
    return func.HttpResponse(json.dumps(doc), status_code=201, mimetype="application/json")


@bp.route(route="chronicles", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def http_chronicles(req: func.HttpRequest) -> func.HttpResponse:
    db = _db()
    if db is None:
        return _fail("Cosmos not configured", 503)
    try:
        body = req.get_json()
    except ValueError:
        body = {}
    name = (body.get("name") or "").strip()
    household_id = (body.get("householdId") or "").strip()
    if not name or not household_id:
        return _fail("Missing name or householdId")
    doc = {"id": str(uuid.uuid4()), "householdId": household_id, "name": name, "createdAt": _now()}
    _container(db, "chronicles").upsert_item(doc)
    logging.info("admin: created chronicle %s", doc["id"])
    return func.HttpResponse(json.dumps(doc), status_code=201, mimetype="application/json")


@bp.route(route="contributors", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def http_contributors(req: func.HttpRequest) -> func.HttpResponse:
    db = _db()
    if db is None:
        return _fail("Cosmos not configured", 503)
    try:
        body = req.get_json()
    except ValueError:
        body = {}
    name = (body.get("name") or "").strip()
    household_id = (body.get("householdId") or "").strip()
    if not name or not household_id:
        return _fail("Missing name or householdId")
    doc = {
        "id": str(uuid.uuid4()),
        "householdId": household_id,
        "name": name,
        "canonicalRelation": body.get("canonicalRelation", ""),
        "displayAlias": body.get("displayAlias", name),
        "role": body.get("role", "Full Contributor"),
        "cadence": body.get("cadence", "weekly"),
        "createdAt": _now(),
    }
    _container(db, "contributors").upsert_item(doc)
    logging.info("admin: created contributor %s", doc["id"])
    return func.HttpResponse(json.dumps(doc), status_code=201, mimetype="application/json")
