"""Config, credentials and cache tests for scripts/seed.py.

Store-specific tests live next door: test_seed_cosmos.py, test_seed_postgres.py.
What stays here is the cross-cutting part — reading the environment, fetching
secrets from Key Vault, pinging the cache — plus the drift guards, which compare
seed.py against infra/ files that no store test would otherwise open.

Pure only: no Azure, no network, no database. Anything that needs a live store
belongs in the Step 5 manual Verify checklist (docs/phase-2/step-5.md), not here
— it cannot run in CI, which has no credentials, and the resources are not free.

Three of these are drift guards rather than behaviour tests: 1536 is recorded in
three places, the secret names in two, and the Redis URL format is decided in
infra. Nothing else catches any of them drifting apart.

Two things deliberately NOT asserted, because nothing in the repo pins them:
  - the exact role strings (AGENTS.md says "N owners + Full Contributor +
    Observer" in prose, not as enum values) — assert counts, not labels;
  - the exact Redis key name — assert that *a* key was written.
Pin them once Phase 3 settles the vocabulary, then tighten.
"""

import re
from pathlib import Path

import pytest
import seed
from fakes import FakeRedis

REPO_ROOT = Path(__file__).resolve().parents[2]
COSMOS_BICEP = REPO_ROOT / "infra" / "modules" / "cosmos.bicep"
COMMON_SH = REPO_ROOT / "scripts" / "common.sh"


def test_embedding_dims_match_cosmos_vector_index():
    """seed.EMBEDDING_DIMS must equal the dimensions in the Cosmos vector index.

    The Postgres `documents.embedding vector(N)` column and the Cosmos
    `memories` vector index have to agree, or embeddings written to one store
    are unreadable in the other. Neither Bicep nor psycopg flags the mismatch:
    a wrong dimension is accepted at insert time and only fails on query.
    """
    bicep = COSMOS_BICEP.read_text()
    match = re.search(r"dimensions:\s*(\d+)", bicep)

    assert match is not None, f"no vector dimensions found in {COSMOS_BICEP}"
    cosmos_dims = int(match.group(1))

    assert seed.EMBEDDING_DIMS == cosmos_dims, (
        f"seed.EMBEDDING_DIMS is {seed.EMBEDDING_DIMS} but {COSMOS_BICEP.name} "
        f"declares dimensions: {cosmos_dims}. Change both, and record the "
        f"decision in docs/phase-2/step-1.md."
    )


def _common_sh_secret_names() -> dict[str, str]:
    """Return the secret-name assignments from scripts/common.sh.

    Parsed rather than sourced: sourcing common.sh needs a populated .env and
    would import Azure names into the test process. The assignments are plain
    NAME="value" lines, so a regex is enough.
    """
    text = COMMON_SH.read_text()
    found = {}
    for name in ("POSTGRES_CONNECTION_STRING_KEY", "REDIS_URL_KEY"):
        match = re.search(rf'^{name}="([^"]*)"', text, re.MULTILINE)
        assert match is not None, f"{name} not assigned in {COMMON_SH}"
        found[name] = match.group(1)
    return found


def test_secret_names_match_common_sh():
    """seed.SECRET_* must equal the names common.sh feeds to Bicep.

    The secret names are written in two places by design: constants here, and
    assignments in common.sh that main.bicepparam reads into platform.bicep and
    on to secret.bicep / containerapp.bicep. Keeping the seed on constants (not
    env lookups) means nothing can redirect it at a different secret at runtime,
    but it also means the two copies can drift.

    The failure they would produce is not obvious: the Container App would
    reference a keyVaultUrl for a secret the vault does not have, and the seed
    would 404 on get_secret. Both surface far from the edit that caused them.
    """
    names = _common_sh_secret_names()

    assert seed.SECRET_POSTGRES == names["POSTGRES_CONNECTION_STRING_KEY"], (
        f"seed.SECRET_POSTGRES is {seed.SECRET_POSTGRES!r} but common.sh sets "
        f"POSTGRES_CONNECTION_STRING_KEY to {names['POSTGRES_CONNECTION_STRING_KEY']!r}. "
        f"Change both."
    )
    assert seed.SECRET_REDIS == names["REDIS_URL_KEY"], (
        f"seed.SECRET_REDIS is {seed.SECRET_REDIS!r} but common.sh sets "
        f"REDIS_URL_KEY to {names['REDIS_URL_KEY']!r}. Change both."
    )


def test_redis_secret_is_a_url_not_an_azure_key_string():
    """The redis secret must be a rediss:// URL, whatever the account produced.

    Azure's listKeys() gives `host:6380,password=...,ssl=True`, which is not a
    URL. Storing that format cost a hand-written parser in seed.py once already,
    and the API would have had to repeat it. Asserting the shape at the point of
    production is what stops it coming back.

    redis.bicep builds the URL; this only pins the scheme so the two agree.
    """
    redis_bicep = (REPO_ROOT / "infra" / "modules" / "redis.bicep").read_text()

    url_output = next(line for line in redis_bicep.splitlines() if "output connectionUrl" in line)
    assert "rediss://" in url_output, (
        "redis.bicep must emit a rediss:// URL for the redis-url secret; "
        "Redis.from_url() cannot parse Azure's key string"
    )


def test_require_env_returns_value(monkeypatch):
    monkeypatch.setenv("MEMWELL_TEST_VAR", "some-value")
    assert seed.require_env("MEMWELL_TEST_VAR") == "some-value"


def test_require_env_rejects_missing(monkeypatch):
    monkeypatch.delenv("MEMWELL_TEST_VAR", raising=False)
    # SystemExit, not ValueError: it stops the seed immediately, and the message
    # names the var plus the fix. It derives from BaseException, so it has to be
    # matched explicitly — pytest.raises(Exception) would not catch it.
    with pytest.raises(SystemExit):
        seed.require_env("MEMWELL_TEST_VAR")


def test_require_env_error_names_the_variable(monkeypatch):
    """The failure has to tell you what is missing and how to fix it."""
    monkeypatch.delenv("MEMWELL_TEST_VAR", raising=False)
    with pytest.raises(SystemExit) as excinfo:
        seed.require_env("MEMWELL_TEST_VAR")
    assert "MEMWELL_TEST_VAR" in str(excinfo.value)


def test_require_env_rejects_empty(monkeypatch):
    """An empty value is as unusable as a missing one — fail on both."""
    monkeypatch.setenv("MEMWELL_TEST_VAR", "")
    with pytest.raises(SystemExit):
        seed.require_env("MEMWELL_TEST_VAR")


# --- resolve_secrets ---------------------------------------------------------


@pytest.fixture
def vault_env(monkeypatch):
    monkeypatch.setenv("VAULT_NAME", "kv-test")
    return monkeypatch


def test_resolve_secrets_reads_both_from_key_vault(vault_env, monkeypatch):
    """Both connection strings come from Key Vault, addressed by vault name."""
    made: dict[str, str] = {}

    class StubSecretClient:
        def __init__(self, vault_url, credential=None, **kwargs):
            made["vault_url"] = vault_url
            self.requested = []

        def get_secret(self, name):
            self.requested.append(name)
            from fakes import FakeSecret

            return FakeSecret(f"value-for-{name}")

    monkeypatch.setattr(seed, "SecretClient", StubSecretClient)

    secrets = seed.resolve_secrets()

    assert made["vault_url"] == "https://kv-test.vault.azure.net"
    assert secrets[seed.SECRET_POSTGRES] == f"value-for-{seed.SECRET_POSTGRES}"
    assert secrets[seed.SECRET_REDIS] == f"value-for-{seed.SECRET_REDIS}"


def test_resolve_secrets_requires_vault_name(vault_env, monkeypatch):
    vault_env.delenv("VAULT_NAME")
    with pytest.raises(SystemExit):
        seed.resolve_secrets()


# --- seed_redis --------------------------------------------------------------


def test_seed_redis_pings_and_expects_pong():
    conn = FakeRedis(pong=True)
    seed.seed_redis(conn)

    assert conn.ping_calls >= 1, "seed must prove connectivity with PING"


def test_seed_redis_writes_an_alias_lookup_key():
    """The alias-lookup key is the cache shape Phase 4a/4b relies on.

    Asserts that a key was written, not its name — the key format is not pinned
    anywhere yet. Tighten once it is.
    """
    conn = FakeRedis()
    seed.seed_redis(conn)

    assert conn.set_calls, "seed must write the alias-lookup key"


def test_seed_redis_fails_loudly_when_ping_fails():
    """A cache that cannot be reached should not pass silently.

    RuntimeError, not AssertionError: the docstring in seed.py says to assert
    ping(), but raising from that assert would surface as an AssertionError,
    which reads like a broken test rather than an unreachable cache.
    """
    conn = FakeRedis(pong=False)
    with pytest.raises(RuntimeError):
        seed.seed_redis(conn)
