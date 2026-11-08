import httpx
from fastapi import FastAPI, File, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

from curator import list_memories, record_memory
from prompter import PromptContext, generate_question
from proxy import FUNCTIONS_BASE_URL, SERVICES_BASE_URL, forward
from telemetry import configure_telemetry

app = FastAPI()
configure_telemetry(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class PromptRequest(BaseModel):
    chronicle_id: str
    contributor_id: str
    alias: str
    persona: str = "warm-family"
    mode: str = "checkin"
    memories: list[str] = []
    new_memory: str | None = None


class PromptResponse(BaseModel):
    question: str


class MemoryRequest(BaseModel):
    chronicle_id: str
    contributor_id: str
    alias: str
    text: str


class MemoryResponse(BaseModel):
    chronicle_id: str
    contributor_id: str
    text: str
    topic: str = ""
    milestone: str | None = None
    date: str | None = None
    alias_at_write_time: str = ""
    alias_change_requested: bool = False
    requested_alias: str | None = None


@app.post("/uploads")
async def upload_file(file: UploadFile = File(...)):  # noqa: B008
    data = await file.read()
    return {"filename": file.filename, "size": len(data), "status": "queued"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    return {"status": "ok"}


@app.post("/prompts", response_model=PromptResponse)
def create_prompt(req: PromptRequest):
    ctx = PromptContext(
        chronicle_id=req.chronicle_id,
        contributor_id=req.contributor_id,
        alias=req.alias,
        persona=req.persona,
        memories=req.memories,
        mode=req.mode,
        new_memory=req.new_memory,
    )
    return PromptResponse(question=generate_question(ctx))


@app.post("/memories", response_model=MemoryResponse)
def create_memory(req: MemoryRequest):
    m = record_memory(req.chronicle_id, req.contributor_id, req.text, req.alias)
    return MemoryResponse(
        chronicle_id=m.chronicle_id,
        contributor_id=m.contributor_id,
        text=m.text,
        topic=m.topic,
        milestone=m.milestone,
        date=m.date,
        alias_at_write_time=m.alias_at_write_time,
        alias_change_requested=m.alias_change_requested,
        requested_alias=m.requested_alias,
    )


@app.get("/memories/{chronicle_id}", response_model=list[MemoryResponse])
def get_memories(chronicle_id: str):
    return [
        MemoryResponse(
            chronicle_id=m.chronicle_id,
            contributor_id=m.contributor_id,
            text=m.text,
            topic=m.topic,
            milestone=m.milestone,
            date=m.date,
            alias_at_write_time=m.alias_at_write_time,
            alias_change_requested=m.alias_change_requested,
            requested_alias=m.requested_alias,
        )
        for m in list_memories(chronicle_id)
    ]


ENTITIES = [
    "households",
    "chronicles",
    "contributors",
    "invites",
    "prompts",
    "memories",
    "transcripts",
    "flags",
    "aliasHistory",
]


async def _proxy_response(resp: httpx.Response) -> Response:
    if resp.status_code == 204:
        return Response(status_code=204)
    try:
        data = resp.json()
    except Exception:
        data = resp.text
    return JSONResponse(status_code=resp.status_code, content=data)


# Entity proxy routes
for _entity in ENTITIES:

    async def _list(entity=_entity, request: Request = None):
        resp = await forward(
            SERVICES_BASE_URL, f"/{entity}", "GET", params=dict(request.query_params)
        )
        return await _proxy_response(resp)

    async def _get(entity=_entity, item_id: str = "", request: Request = None):
        resp = await forward(
            SERVICES_BASE_URL, f"/{entity}/{item_id}", "GET", params=dict(request.query_params)
        )
        return await _proxy_response(resp)

    async def _create(entity=_entity, request: Request = None):
        body = (
            await request.json()
            if request.headers.get("content-type", "").startswith("application/json")
            else None
        )
        resp = await forward(
            SERVICES_BASE_URL,
            f"/{entity}",
            "POST",
            json_body=body,
            params=dict(request.query_params),
        )
        return await _proxy_response(resp)

    async def _update(entity=_entity, item_id: str = "", request: Request = None):
        body = (
            await request.json()
            if request.headers.get("content-type", "").startswith("application/json")
            else None
        )
        resp = await forward(
            SERVICES_BASE_URL,
            f"/{entity}/{item_id}",
            "PUT",
            json_body=body,
            params=dict(request.query_params),
        )
        return await _proxy_response(resp)

    async def _patch(entity=_entity, item_id: str = "", request: Request = None):
        body = (
            await request.json()
            if request.headers.get("content-type", "").startswith("application/json")
            else None
        )
        resp = await forward(
            SERVICES_BASE_URL,
            f"/{entity}/{item_id}",
            "PATCH",
            json_body=body,
            params=dict(request.query_params),
        )
        return await _proxy_response(resp)

    async def _delete(entity=_entity, item_id: str = "", request: Request = None):
        resp = await forward(
            SERVICES_BASE_URL, f"/{entity}/{item_id}", "DELETE", params=dict(request.query_params)
        )
        return await _proxy_response(resp)

    app.add_api_route(f"/{_entity}", _list, methods=["GET"])
    app.add_api_route(f"/{_entity}/{{item_id}}", _get, methods=["GET"])
    app.add_api_route(f"/{_entity}", _create, methods=["POST"])
    app.add_api_route(f"/{_entity}/{{item_id}}", _update, methods=["PUT"])
    app.add_api_route(f"/{_entity}/{{item_id}}", _patch, methods=["PATCH"])
    app.add_api_route(f"/{_entity}/{{item_id}}", _delete, methods=["DELETE"])


# Function proxy: invite claim
@app.post("/invites/claim")
async def claim_invite(request: Request):
    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}
    token = (body.get("token") if isinstance(body, dict) else None) or request.query_params.get(
        "token", ""
    )
    resp = await forward(FUNCTIONS_BASE_URL, "/api/invites/claim", "POST", params={"token": token})
    return await _proxy_response(resp)
