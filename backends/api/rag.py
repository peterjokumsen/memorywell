"""Shared retrieval helpers for pgvector-backed memory search.

The Prompter (and later the Curator/Guardian) use these helpers to fetch
memories relevant to a (chronicle, contributor) pair. Retrieval is SQL-only:
callers supply an embedding vector; this module never calls an embedding model.
"""

from __future__ import annotations

from collections.abc import Sequence
from typing import Any


def build_filter(chronicle_id: str, contributor_id: str) -> dict[str, str]:
    """Return the metadata filter dict used by retrieval queries."""
    return {"chronicle_id": chronicle_id, "contributor_id": contributor_id}


def _to_pgvector(embedding: Sequence[float]) -> str:
    return "[" + ",".join(repr(float(x)) for x in embedding) + "]"


def retrieve(
    conn: Any,
    *,
    chronicle_id: str,
    contributor_id: str,
    embedding: Sequence[float],
    top_k: int = 5,
) -> list[str]:
    """Retrieve the top-k memory texts for a (chronicle, contributor) pair.

    ``conn`` is any DB-API compatible connection exposing ``cursor()``.
    Metadata filters are applied on the ``documents`` table's ``metadata``
    jsonb column; ordering is by cosine distance to ``embedding``.
    """
    sql = (
        "SELECT content FROM documents "
        "WHERE metadata->>'chronicle_id' = %s "
        "AND metadata->>'contributor_id' = %s "
        "ORDER BY embedding <=> %s::vector "
        "LIMIT %s"
    )
    params = (chronicle_id, contributor_id, _to_pgvector(embedding), top_k)
    with conn.cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return [row[0] for row in rows]


# Aliases for naming flexibility across callers/tests.
retrieve_memories = retrieve
search = retrieve


def retrieve_by_text(*args: Any, **kwargs: Any) -> list[str]:
    """Placeholder: embedding generation is deferred to a later step."""
    raise NotImplementedError("retrieve_by_text requires an embedding model; not implemented yet")
