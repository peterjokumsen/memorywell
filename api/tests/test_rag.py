from unittest.mock import MagicMock

from rag import build_filter, retrieve, retrieve_memories


def _make_conn(rows):
    conn = MagicMock()
    cur = MagicMock()
    cur.fetchall.return_value = rows
    conn.cursor.return_value.__enter__.return_value = cur
    return conn, cur


def test_build_filter():
    assert build_filter("c1", "u1") == {"chronicle_id": "c1", "contributor_id": "u1"}


def test_retrieve_returns_strings():
    conn, cur = _make_conn([("First steps",), ("Birthday",)])
    out = retrieve(conn, chronicle_id="c1", contributor_id="u1", embedding=[0.1, 0.2], top_k=2)
    assert out == ["First steps", "Birthday"]
    cur.execute.assert_called_once()
    params = cur.execute.call_args[0][1]
    assert params[0] == "c1"
    assert params[1] == "u1"
    assert params[3] == 2


def test_retrieve_memories_alias():
    conn, _ = _make_conn([])
    assert retrieve_memories(conn, chronicle_id="c1", contributor_id="u1", embedding=[0.0]) == []
