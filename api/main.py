from fastapi import FastAPI
from pydantic import BaseModel

from curator import list_memories, record_memory
from prompter import PromptContext, generate_question

app = FastAPI()


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
