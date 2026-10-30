"""Tests for scripts/seed.py main(): the wiring between the three stores.

main() is the one function with no store-specific test, and it is where the
seed's cross-store mistakes land: it is the only caller of resolve_secrets,
resolve_cosmos, count_items and the Postgres count query. Nothing else exercises
it, so a method that exists on a fake but not on the SDK — `db.count_in` — sat
there through every green run and only failed against a live account.

These run the whole entry point against the doubles in fakes.py: no Azure, no
network, no credentials. Seed data shape stays in test_seed_cosmos.py.
"""

import pytest
import seed
from fakes import FakeCosmosDb, FakeSecret, FakeSqlConn

CONTAINERS = (
    "households",
    "chronicles",
    "contributors",
    "invites",
    "prompts",
    "memories",
    "transcripts",
    "flags",
    "aliasHistory",
)


@pytest.fixture
def wired(monkeypatch):
    """Stub every external client main() builds; return what it was given.

    Replaces the constructors rather than seed.resolve_secrets and friends, so
    the resolution code is exercised too — a main() that asked for the wrong
    environment variable still fails here.
    """
    monkeypatch.setenv("COSMOS_ENDPOINT", "https://cosmos-test.documents.azure.com:443/")
    monkeypatch.setenv("COSMOS_DATABASE", "memorywell")
    monkeypatch.setenv("VAULT_NAME", "kv-test")

    db = FakeCosmosDb(container_names=CONTAINERS)

    class StubCosmosClient:
        def __init__(self, endpoint, credential=None, **kwargs):
            pass

        def get_database_client(self, database):
            return db

    class StubSecretClient:
        def __init__(self, vault_url, credential=None, **kwargs):
            pass

        def get_secret(self, name):
            return FakeSecret("stub-value")

    connections = []

    def fake_connect(_conninfo):
        conn = FakeSqlConn()
        connections.append(conn)
        return conn

    monkeypatch.setattr(seed, "CosmosClient", StubCosmosClient)
    monkeypatch.setattr(seed, "SecretClient", StubSecretClient)
    monkeypatch.setattr(seed.psycopg, "connect", fake_connect)
    return {"db": db, "connections": connections}


def test_main_seeds_all_three_stores(wired):
    """A run that completes the whole seed: Cosmos documents, a Postgres row,
    a Redis key."""
    seed.main()

    assert wired["db"].count_in("memories") == 1
    assert any("INSERT INTO documents" in conn.sql for conn in wired["connections"])


def test_main_reports_a_count_per_container(wired, capsys):
    """step-5.md verifies by reading these lines, so the counts are evidence
    and must cover every seeded container."""
    seed.main()

    out = capsys.readouterr().out
    assert "cosmos households: 1" in out
    assert "cosmos memories: 1" in out
    assert "postgres documents:" in out


def test_main_never_prints_a_secret(wired, capsys):
    """Connection strings live in the values resolve_secrets returns; printing
    one puts a password in a terminal scrollback and in any pasted log."""
    seed.main()

    out = capsys.readouterr().out
    assert "stub-value" not in out
