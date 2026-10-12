# Phase 1 · Step 4 — Skeleton API (stub only)

**Skeleton API (stub only).** `api/main.py` with `/health` and `/ready`
returning `{"status":"ok"}`; `api/requirements.txt` (fastapi + uvicorn);
`api/Dockerfile` (slim python, expose 8000, run uvicorn). No agent code,
no DB clients.

Stub shapes (write them yourself, keep them this small):

```python
# api/main.py — stub
from fastapi import FastAPI
app = FastAPI()

@app.get("/health")
def health(): return {"status": "ok"}

@app.get("/ready")
def ready(): return {"status": "ok"}
```

```dockerfile
# api/Dockerfile — stub
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py ./
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

`.python-version` (content `3.11`) is a local `uv`/pyenv toolchain hint,
auto-generated and git-ignored — the build pins `python:3.11-slim` in
`api/Dockerfile` instead.

## Verify

- [x] `api/tests/test_main.py` asserts `/health` + `/ready` return
      `{"status":"ok"}` (TestClient, no live Azure needed).
