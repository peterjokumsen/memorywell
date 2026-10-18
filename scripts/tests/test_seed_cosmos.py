"""Cosmos-facing tests for scripts/seed.py: client resolution, containers,
upserts, and the seeded household.

Pure: FakeCosmosDb stands in for the database. Live Cosmos behaviour — and the
run-twice idempotency check against a real account — is verified manually
(docs/phase-2/step-5.md).

Role labels are not asserted, only counts: AGENTS.md describes the roles in
prose, so the vocabulary is not pinned to string values until Phase 3.
"""

import pytest
import seed
from fakes import FakeCosmosDb, FakePartitionKey

# PLAN.md:63 — none | special-occasions | monthly | weekly.
VALID_CADENCES = {"none", "special-occasions", "monthly", "weekly"}


# --- resolve_cosmos ----------------------------------------------------------


@pytest.fixture
def cosmos_env(monkeypatch):
    monkeypatch.setenv("COSMOS_ENDPOINT", "https://cosmos-test.documents.azure.com:443/")
    monkeypatch.setenv("COSMOS_DATABASE", "memorywell")
    return monkeypatch


def test_resolve_cosmos_uses_env_and_identity(cosmos_env, monkeypatch):
    """Cosmos is keyless: endpoint + database from env, credential from the SDK.

    The account has disableLocalAuth: true, so there is no key to pass and
    passing one would be wrong, not merely redundant.
    """
    created = {}

    class StubClient:
        def __init__(self, endpoint, credential=None, **kwargs):
            created["endpoint"] = endpoint
            created["credential"] = credential
            self.db = FakeCosmosDb()

    monkeypatch.setattr(seed, "CosmosClient", StubClient)

    client, database, endpoint = seed.resolve_cosmos()

    assert endpoint == "https://cosmos-test.documents.azure.com:443/"
    assert database == "memorywell"
    assert created["endpoint"] == "https://cosmos-test.documents.azure.com:443/"
    assert created["credential"] is not None, "Cosmos must authenticate with an identity"
    assert client is not None


def test_resolve_cosmos_requires_endpoint(cosmos_env, monkeypatch):
    """A missing COSMOS_ENDPOINT must stop the seed before any Azure call."""
    cosmos_env.delenv("COSMOS_ENDPOINT")
    with pytest.raises(SystemExit):
        seed.resolve_cosmos()


# --- container ---------------------------------------------------------------


def test_container_finds_existing_container_without_recreating():
    """The containers already exist (deployed by cosmos.bicep).

    Recreating with different settings would silently diverge from the deployed
    indexing policy, so the happy path is finding, not creating.
    """
    db = FakeCosmosDb(container_names=("memories",))
    seed.container(db, "memories")

    assert db.create_container_calls == [], "memories already exists; do not recreate it"


def test_container_creates_with_chronicle_partition_key():
    """Partition keys are fixed by cosmos.bicep: /chronicleId for the
    chronicle-scoped containers, /id for households, /householdId for the rest.
    This asserts memories, which is the one that also carries the vector index."""
    db = FakeCosmosDb()
    seed.container(db, "memories")

    assert len(db.create_container_calls) == 1
    call = db.create_container_calls[0]
    pk = call["partition_key"]
    path = pk.path if isinstance(pk, FakePartitionKey) else getattr(pk, "path", None)
    assert path == "/chronicleId", f"memories partitions on /chronicleId, got {path!r}"


# --- upsert ------------------------------------------------------------------


def test_upsert_uses_upsert_not_create():
    """create_item raises 409 on the second run; upsert_item is the contract."""
    db = FakeCosmosDb(container_names=("memories",))
    seed.upsert(db, "memories", {"id": "mem-seed-1", "body": "x"})

    container = db.get_container_client("memories")
    assert container.create_calls == [], "must never use create_item"
    assert len(container.upsert_calls) == 1


def test_upsert_is_safe_to_repeat():
    """Running the same doc twice leaves one item, not two."""
    db = FakeCosmosDb(container_names=("memories",))
    seed.upsert(db, "memories", {"id": "mem-seed-1", "body": "x"})
    seed.upsert(db, "memories", {"id": "mem-seed-1", "body": "x"})

    assert db.count_in("memories") == 1, "second write must overwrite, not duplicate"


# --- seed_cosmos -------------------------------------------------------------


@pytest.fixture
def seeded():
    """Run seed_cosmos against a db holding all nine containers."""
    names = (
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
    db = FakeCosmosDb(container_names=names)
    seed.seed_cosmos(db)
    return db


def test_seed_cosmos_writes_one_household(seeded):
    assert seeded.count_in("households") == 1


def test_seed_cosmos_writes_both_chronicles(seeded):
    assert seeded.count_in("chronicles") == len(seed.CHRONICLE_IDS) == 2


def test_seed_cosmos_writes_four_contributors(seeded):
    """2 owners + 1 Full Contributor + 1 Observer (AGENTS.md).

    Counts, not role labels: the vocabulary is prose in AGENTS.md and is not
    pinned to string values yet.
    """
    assert seeded.count_in("contributors") == 4


def test_seed_cosmos_contributors_have_owner_managed_fields(seeded):
    """contact / relation / status are owner-managed (PLAN.md:31-32)."""
    for doc in seeded.docs_in("contributors"):
        assert {"contact", "relation", "status"} <= set(doc), (
            f"contributor {doc.get('id')} missing owner-managed fields"
        )


def test_seed_cosmos_contributors_have_per_chronicle_maps(seeded):
    """displayAlias and promptCadence are per-chronicle, contributor-managed maps."""
    for doc in seeded.docs_in("contributors"):
        assert "displayAlias" in doc, f"contributor {doc.get('id')} missing displayAlias map"
        assert "promptCadence" in doc, f"contributor {doc.get('id')} missing promptCadence map"


def test_seed_cosmos_prompt_cadence_values_are_valid(seeded):
    """PLAN.md:63 fixes the enum: none | special-occasions | monthly | weekly."""
    for doc in seeded.docs_in("contributors"):
        for chronicle_id, cadence in doc.get("promptCadence", {}).items():
            assert cadence in VALID_CADENCES, (
                f"contributor {doc.get('id')} chronicle {chronicle_id} has "
                f"promptCadence {cadence!r}, expected one of {sorted(VALID_CADENCES)}"
            )


def test_seed_cosmos_exercises_weekly_and_default_monthly(seeded):
    """The brief asks for one 'weekly' and one default 'monthly'.

    monthly is the default per PLAN.md:63, so a seed that only ever sets
    'weekly' would not prove the default path works.
    """
    cadences = {
        cadence
        for doc in seeded.docs_in("contributors")
        for cadence in doc.get("promptCadence", {}).values()
    }
    assert "weekly" in cadences, "expected at least one 'weekly' cadence"
    assert "monthly" in cadences, "expected at least one 'monthly' cadence (the default)"


def test_seed_cosmos_writes_one_memory(seeded):
    assert seeded.count_in("memories") == 1


def test_seed_cosmos_memory_snapshots_the_authoring_alias(seeded):
    """aliasAtWriteTime freezes the alias used at write time (AGENTS.md), so a
    later rename cannot retroactively change what a memory appears to have said."""
    memory = seeded.docs_in("memories")[0]
    assert "aliasAtWriteTime" in memory, "memory must snapshot aliasAtWriteTime"
    assert memory.get("contributorId"), "memory must record contributorId"


def test_seed_cosmos_memory_is_multi_turn_ready(seeded):
    """promptId / parentMemoryId / turnCount / conversationId exist even though
    the flow is single-shot (AGENTS.md)."""
    memory = seeded.docs_in("memories")[0]
    for field in ("promptId", "parentMemoryId", "turnCount", "conversationId"):
        assert field in memory, f"memory missing {field} (schema is multi-turn-ready)"


def test_seed_cosmos_is_idempotent():
    """Running twice leaves identical counts — the Step 5 verify check."""
    names = ("households", "chronicles", "contributors", "memories")
    first = FakeCosmosDb(container_names=names)
    seed.seed_cosmos(first)
    counts_first = {name: first.count_in(name) for name in names}

    second = FakeCosmosDb(container_names=names)
    seed.seed_cosmos(second)
    counts_second = {name: second.count_in(name) for name in names}

    assert counts_first == counts_second
