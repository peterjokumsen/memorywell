"""Postgres-facing tests for scripts/seed.py: the `documents` schema and the
upsert that mirrors a Cosmos memory.

Pure: FakeSqlConn records the SQL so the assertions are about statement shape
rather than results. Live Postgres behaviour is verified manually
(docs/phase-2/step-5.md) — notably the `\\d documents` listing, which recorded SQL
cannot prove.
"""

import re

import seed
from fakes import FakeSqlConn

# --- postgres_schema ---------------------------------------------------------


def test_postgres_schema_creates_extension_and_table():
    """Both statements must run: the allowlist permits vector, it does not install it."""
    conn = FakeSqlConn()
    seed.postgres_schema(conn)

    sql = conn.sql
    assert "CREATE EXTENSION" in sql and "vector" in sql
    assert "CREATE TABLE" in sql and "documents" in sql


def test_postgres_schema_is_idempotent():
    """IF NOT EXISTS on both: re-running must not raise, and a torn-down
    Postgres has to self-heal when the seed runs again."""
    conn = FakeSqlConn()
    seed.postgres_schema(conn)

    sql = conn.sql
    assert "IF NOT EXISTS" in sql, "schema DDL must be idempotent"


def test_postgres_schema_uses_quoted_camelcase_identifiers():
    """Postgres folds unquoted identifiers to lowercase.

    Phase 4a queries "chronicleId"; an unquoted CREATE TABLE makes the column
    chronicleid and that query silently returns nothing. Same for createdAt.
    """
    conn = FakeSqlConn()
    seed.postgres_schema(conn)

    sql = conn.sql
    assert '"chronicleId"' in sql, "camelCase columns must be quoted"
    assert '"createdAt"' in sql, "camelCase columns must be quoted"


def test_postgres_schema_declares_vector_and_jsonb_columns():
    """The two column types step-2.md specifies: vector(N) and jsonb."""
    conn = FakeSqlConn()
    seed.postgres_schema(conn)

    sql = conn.sql
    assert re.search(r"embedding\s+vector\(\d+\)", sql), "embedding must be vector(N)"
    assert "jsonb" in sql, "metadata must be jsonb"


def test_postgres_schema_embedding_dimension_matches_cosmos():
    """The DDL's vector(N) must be EMBEDDING_DIMS, which
    test_embedding_dims_match_cosmos_vector_index already ties to the Cosmos
    index. This closes the loop on the literal in the SQL."""
    conn = FakeSqlConn()
    seed.postgres_schema(conn)

    assert f"vector({seed.EMBEDDING_DIMS})" in conn.sql


# --- seed_documents ----------------------------------------------------------


def test_seed_documents_upserts_on_id():
    """ON CONFLICT (id) DO UPDATE — the verify check runs the seed twice."""
    conn = FakeSqlConn()
    seed.seed_documents(conn, {"id": "mem-seed-1", "body": "a memory"})

    sql = conn.sql
    assert "INSERT INTO documents" in sql
    assert "ON CONFLICT" in sql, "must upsert, not plain INSERT (second run would duplicate)"


def test_seed_documents_uses_a_uuid_id():
    """id is a uuid column, so the row gets its own id, not the Cosmos string id.

    Reusing the Cosmos id would either fail the uuid cast or force both stores
    to share a key, which they do not.
    """
    conn = FakeSqlConn()
    seed.seed_documents(conn, {"id": "mem-seed-1", "body": "a memory"})

    sql = conn.sql.upper()
    assert "UUID" in sql, "documents.id is uuid per step-2.md"


def test_seed_documents_writes_null_embedding():
    """No embedding at seed time: generation is Phase 4a via the change feed."""
    conn = FakeSqlConn()
    seed.seed_documents(conn, {"id": "mem-seed-1", "body": "a memory"})

    assert "embedding" in conn.sql
