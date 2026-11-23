import json

import azure.functions as func

bp = func.Blueprint()


def _entity_schema(name: str, required: list[str]) -> dict:
    base_required = []
    properties = {
        "id": {"type": "string"},
        "createdAt": {"type": "string", "format": "date-time"},
        "updatedAt": {"type": "string", "format": "date-time"},
        "isDeleted": {"type": "boolean"},
        "deletedAt": {"type": "string", "format": "date-time", "nullable": True},
    }
    for field in required:
        if field not in properties:
            properties[field] = {"type": "string"}
    all_required = list(dict.fromkeys(required + base_required))
    return {
        "type": "object",
        "properties": properties,
        "required": all_required,
        "additionalProperties": True,
    }


ENTITIES = [
    ("households", "id", ["name"], {}),
    ("chronicles", "householdId", ["name", "householdId"], {}),
    ("contributors", "householdId", ["name", "householdId"], {}),
    ("invites", "householdId", ["householdId"], {}),
    ("prompts", "chronicleId", ["chronicleId"], {}),
    ("memories", "chronicleId", ["chronicleId"], {}),
    ("transcripts", "chronicleId", ["chronicleId"], {}),
    ("flags", "chronicleId", ["chronicleId"], {}),
    ("aliasHistory", "chronicleId", ["chronicleId"], {}),
]

LIST_PARAMS = [
    {"name": "householdId", "in": "query", "schema": {"type": "string"}},
    {"name": "chronicleId", "in": "query", "schema": {"type": "string"}},
    {"name": "contributorId", "in": "query", "schema": {"type": "string"}},
    {"name": "includeDeleted", "in": "query", "schema": {"type": "string"}},
]


def _build_spec() -> dict:
    paths = {}
    schemas = {}
    for name, _pk, required, _defaults in ENTITIES:
        schema_name = name[0].upper() + name[1:]
        # naive singular-ish name for schema (keep entity plural for simplicity)
        schemas[schema_name] = _entity_schema(name, required)

        collection_path = f"/api/{name}"
        item_path = f"/api/{name}/{{id}}"

        paths[collection_path] = {
            "get": {
                "parameters": LIST_PARAMS,
                "responses": {"200": {"description": "OK"}},
            },
            "post": {
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {"$ref": f"#/components/schemas/{schema_name}"}
                        }
                    },
                },
                "responses": {"201": {"description": "Created"}},
            },
            "options": {"responses": {"204": {"description": "No Content"}}},
        }
        paths[item_path] = {
            "get": {
                "parameters": [
                    {"name": "id", "in": "path", "required": True, "schema": {"type": "string"}}
                ],
                "responses": {"200": {"description": "OK"}, "404": {"description": "Not Found"}},
            },
            "put": {
                "parameters": [
                    {"name": "id", "in": "path", "required": True, "schema": {"type": "string"}}
                ],
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {"$ref": f"#/components/schemas/{schema_name}"}
                        }
                    },
                },
                "responses": {"200": {"description": "OK"}},
            },
            "patch": {
                "parameters": [
                    {"name": "id", "in": "path", "required": True, "schema": {"type": "string"}}
                ],
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {"$ref": f"#/components/schemas/{schema_name}"}
                        }
                    },
                },
                "responses": {"200": {"description": "OK"}},
            },
            "delete": {
                "parameters": [
                    {"name": "id", "in": "path", "required": True, "schema": {"type": "string"}}
                ],
                "responses": {"204": {"description": "No Content"}},
            },
            "options": {"responses": {"204": {"description": "No Content"}}},
        }

    spec = {
        "openapi": "3.0.0",
        "info": {"title": "Memorywell BFF", "version": "1.0.0"},
        "paths": paths,
        "components": {"schemas": schemas},
    }
    return spec


@bp.route(route="openapi.json", methods=["GET"])
def openapi(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps(_build_spec()),
        mimetype="application/json",
        status_code=200,
    )
