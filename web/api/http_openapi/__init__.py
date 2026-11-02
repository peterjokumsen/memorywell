import json
import os

import azure.functions as func

bp = func.Blueprint()


@bp.route(route="openapi.json", methods=["GET", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
def openapi(req):
    if req.method == "OPTIONS":
        return func.HttpResponse("", status_code=204, headers={"Access-Control-Allow-Origin": "*"})
    path = os.path.join(os.path.dirname(__file__), "..", "openapi.json")
    try:
        with open(path) as f:
            spec = f.read()
    except FileNotFoundError:
        spec = json.dumps(
            {
                "openapi": "3.0.0",
                "info": {"title": "MemoryWell BFF", "version": "1.0.0"},
                "paths": {},
            }
        )
    return func.HttpResponse(
        spec,
        status_code=200,
        mimetype="application/json",
        headers={"Access-Control-Allow-Origin": "*"},
    )
