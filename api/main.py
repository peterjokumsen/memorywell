from fastapi import FastAPI
from pydantic import BaseModel

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
