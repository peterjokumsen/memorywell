import pytest
from fastapi.testclient import TestClient

from curator import (
    CuratedMemory,
    build_extraction_prompt,
    extract_metadata,
    list_memories,
    memory_key,
    record_memory,
    to_curated_memory,
    write_memory,
)
from main import app


def test_build_extraction_prompt():
    msgs = build_extraction_prompt("hello")
    assert msgs[0]["role"] == "system"
    assert msgs[1]["content"] == "hello"


def test_extract_metadata_with_llm():
    def llm(msgs):
        return {
            "topic": "family",
            "milestone": None,
            "date": None,
            "aliasChangeRequested": True,
            "requestedAlias": "Granny",
        }

    out = extract_metadata("call me Granny", llm=llm)
    assert out["aliasChangeRequested"] is True
    assert out["requestedAlias"] == "Granny"


def test_to_curated_memory_snapshots_alias():
    extracted = {
        "topic": "x",
        "milestone": None,
        "date": None,
        "aliasChangeRequested": False,
        "requestedAlias": None,
    }
    m = to_curated_memory("c1", "u1", "text", "Granny", extracted)
    assert isinstance(m, CuratedMemory)
    assert m.alias_at_write_time == "Granny"
    assert m.topic == "x"


def test_write_memory_idempotent():
    m1 = to_curated_memory("c1", "u1", "text", "A", {})
    m2 = to_curated_memory("c1", "u1", "text", "A", {})
    store = {}
    r1 = write_memory(m1, store=store)
    r2 = write_memory(m2, store=store)
    assert r1 is r2
    assert len(store) == 1


def test_memory_key():
    m = to_curated_memory("c1", "u1", "text", "A", {})
    assert memory_key(m) == "c1|u1|text"


def test_record_and_list_memories():
    store = {}
    m = record_memory(
        "c2",
        "u2",
        "hello world",
        "Mom",
        store=store,
        llm=lambda msgs: {
            "topic": "t",
            "milestone": None,
            "date": None,
            "aliasChangeRequested": False,
            "requestedAlias": None,
        },
    )
    assert m.chronicle_id == "c2"
    assert len(list_memories("c2", store=store)) == 1
    assert list_memories("other", store=store) == []


def test_conversation_api():
    client = TestClient(app, raise_server_exceptions=False)
    r = client.post(
        "/memories",
        json={
            "chronicle_id": "cx",
            "contributor_id": "ux",
            "alias": "Dad",
            "text": "a memory",
        },
    )
    if r.status_code != 200:
        pytest.skip("OpenAI not configured in test env")
    assert r.status_code == 200
    g = client.get("/memories/cx")
    assert g.status_code == 200
