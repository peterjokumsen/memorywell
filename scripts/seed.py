"""Phase 2 seed: Postgres schema + one household of sample data.

Idempotent. Running it twice leaves identical row counts in Cosmos, Postgres
and Redis, which is what the Step 5 verify check relies on.

Usage:
    source scripts/common.sh && .venv/bin/python scripts/seed.py

`source scripts/common.sh` first: this script reads COSMOS_ENDPOINT,
COSMOS_DATABASE and VAULT_NAME from the environment rather than deriving
them, so the shell stays the single source of truth for resource names.

Credentials come from Key Vault via DefaultAzureCredential — never from .env
and never from a literal in this file. See docs/phase-2/step-5.md.
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import UTC, datetime

# These imports are unused until the function bodies below are filled in, which
# is why they carry noqa — the scaffold has to lint clean so the pre-commit
# hook and CI pass while it is still a stub. Drop the noqa as each is used.
import psycopg
import redis
from azure.cosmos import CosmosClient, PartitionKey  # noqa: F401
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from psycopg.types.json import Json

# --- Config -----------------------------------------------------------------
#
# Required env vars: COSMOS_ENDPOINT, COSMOS_DATABASE, VAULT_NAME.
# Read them through a helper rather than inline os.environ so a missing value
# names itself in the error instead of raising KeyError with no context.

# Key Vault secret names. Application constants, identical in every environment,
# and deliberately NOT read from the environment: routing them through
# require_env would imply they are tunable, which is exactly the drift the
# COSMOS_DATABASE comment in common.sh warns about. scripts/common.sh owns the
# same two names for the Bicep side (main.bicepparam -> _types.bicep ->
# platform.bicep -> secret.bicep); the drift test in tests/test_seed.py fails if
# these two ever diverge.
SECRET_POSTGRES = "postgres-connection-string"
SECRET_REDIS = "redis-url"

# Step 2 fixed this at 1536 to match the Cosmos memories vector index
# (docs/phase-2/step-1.md). Changing one side means changing both.
EMBEDDING_DIMS = 1536

# Fixed ids, not generated: an upsert keyed on a stable id is what makes the
# script idempotent. A fresh uuid per run would duplicate every document.
HOUSEHOLD_ID = "hh-seed-1"
CHRONICLE_IDS = ("chron-seed-1", "chron-seed-2")
MEMORY_ID = "mem-seed-1"

# Redis key for the chronicle -> alias lookup. Fixed string rather than derived
# from the household id: this is one household's seed, and Phase 4a will define
# the real key scheme (possibly namespaced per household). Prefix makes the
# intent obvious and keeps it from colliding once other households exist.
ALIAS_LOOKUP_KEY = "seed:alias-lookup"


def now_iso() -> str:
    """Return the current UTC time as an ISO 8601 string ending in `Z`.

    Cosmos stores JSON and the SDK serializes item bodies with the stdlib json
    encoder, which has no handler for datetime: an item carrying one raises
    `TypeError: Object of type datetime is not JSON serializable` at upsert, and
    it does so on the first document written, so the traceback points at
    upsert_item rather than at the `createdAt` that caused it.

    A string is what Cosmos holds anyway once written. It round-trips in both
    directions the seed needs: `datetime.fromisoformat` reads the `Z` form back
    on 3.11+, and Postgres casts the same text to timestamptz on insert.
    """
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _contributors() -> list[dict]:
    """The four membership rows: 2 owners + 1 Full Contributor + 1 Observer.

    Each doc carries both sides of the AGENTS.md split — owner-managed
    (contact, relation, status) and contributor-managed (displayAlias,
    promptCadence, per chronicle).

    Role strings are NOT pinned by any test: AGENTS.md describes the roles in
    prose, so these are the labels used here and Phase 3 may settle them into an
    enum. The tests assert counts, not labels.

    Cadence values are the PLAN.md enum: none | special-occasions | monthly |
    weekly, with monthly the default. The mix deliberately includes a 'weekly'
    (explicitly set) and a 'monthly' (the default path), plus 'none', so a seed
    that only exercised one branch would still pass.
    """
    chron1, chron2 = CHRONICLE_IDS
    return [
        {
            "id": "contrib-seed-1",
            "role": "Owner",
            "contact": "gaga@example.com",
            "relation": "Grandma",
            "status": "active",
            "displayAlias": {chron1: "Gaga", chron2: "Granny"},
            "promptCadence": {chron1: "weekly", chron2: "monthly"},
        },
        {
            "id": "contrib-seed-2",
            "role": "Owner",
            "contact": "mum@example.com",
            "relation": "Daughter",
            "status": "active",
            "displayAlias": {chron1: "Mum", chron2: "Mum"},
            "promptCadence": {chron1: "monthly", chron2: "monthly"},
        },
        {
            "id": "contrib-seed-3",
            "role": "Full Contributor",
            "contact": "aunt@example.com",
            "relation": "Aunt",
            "status": "active",
            "displayAlias": {chron1: "Auntie", chron2: "Auntie"},
            "promptCadence": {chron1: "monthly", chron2: "none"},
        },
        {
            "id": "contrib-seed-4",
            "role": "Observer",
            "contact": "uncle@example.com",
            "relation": "Uncle",
            "status": "active",
            "displayAlias": {chron1: "Uncle", chron2: "Uncle"},
            "promptCadence": {chron1: "none", chron2: "none"},
        },
    ]


class ConfigNames:
    """Environment variable names"""

    cosmos_endpoint: str = "COSMOS_ENDPOINT"
    cosmos_database: str = "COSMOS_DATABASE"
    vault_name: str = "VAULT_NAME"


CONFIG_NAMES = ConfigNames()

# --- Config resolution ------------------------------------------------------


def require_env(name: str) -> str:
    """Return env var `name`, or exit with a message naming it.

    Raises SystemExit on a missing or empty value: the variables come from
    `source scripts/common.sh`, so either case means the seed was launched
    without the right environment and every later call would fail more
    confusingly.
    """
    value = os.environ.get(name, "")
    if not value:
        raise SystemExit(f"{name} is not set. Run: source scripts/common.sh")
    return value


def resolve_cosmos() -> tuple[CosmosClient, str, str]:
    """Return (client, database_name, endpoint) from env + DefaultAzureCredential."""
    endpoint = require_env(CONFIG_NAMES.cosmos_endpoint)
    client = CosmosClient(endpoint, credential=DefaultAzureCredential())
    database_name = require_env(CONFIG_NAMES.cosmos_database)
    return (client, database_name, endpoint)


def resolve_secrets() -> dict[str, str]:
    """Return {SECRET_POSTGRES: value, SECRET_REDIS: value} from Key Vault."""
    client = SecretClient(
        vault_url=f"https://{require_env(CONFIG_NAMES.vault_name)}.vault.azure.net",
        credential=DefaultAzureCredential(),
    )
    return {name: client.get_secret(name).value for name in (SECRET_POSTGRES, SECRET_REDIS)}


# --- Postgres ---------------------------------------------------------------


def postgres_schema(conn: psycopg.Connection) -> None:
    """Create the vector extension and `documents` table if absent.

    Schema is fixed by docs/phase-2/step-2.md — copy it, do not redesign it:

        id uuid pk, chronicleId, contributorId, topic, createdAt,
        embedding vector(1536), metadata jsonb

    Two things that spec implies and that are easy to miss:
      - camelCase identifiers need quoting ("chronicleId"), because Postgres
        folds unquoted names to lowercase and Phase 4a queries the quoted form.
      - CREATE EXTENSION vector is required, not optional: step 2's
        azure.extensions allowlist makes the extension permitted, not installed.

    IF NOT EXISTS on both statements keeps this idempotent and lets a torn-down
    Postgres heal itself the next time the seed runs.
    """
    conn.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # EMBEDDING_DIMS, not a literal 1536: it is drift-guarded against the Cosmos
    # vector index in tests/test_seed.py, so the two stores cannot disagree.
    conn.execute(
        f"""
        CREATE TABLE IF NOT EXISTS documents (
            id              uuid PRIMARY KEY,
            "chronicleId"   text,
            "contributorId" text,
            topic           text,
            "createdAt"     timestamptz,
            embedding       vector({EMBEDDING_DIMS}),
            metadata        jsonb
        )
        """
    )

    # psycopg is not in autocommit mode by default, so without this the DDL is
    # rolled back when the connection closes.
    conn.commit()


def seed_documents(conn: psycopg.Connection, memory: dict) -> None:
    """Upsert the `documents` row mirroring the seeded Cosmos memory.

    `id` is a uuid column, so the row gets its own id rather than reusing the
    Cosmos document id — the two stores key independently.

    The id is uuid5(namespace, cosmos_doc_id), NOT uuid4(): it has to be stable
    across runs for ON CONFLICT to ever fire. A fresh uuid4 each run would never
    collide, so every seed would append another row and the "run it twice, counts
    match" check in docs/phase-2/step-5.md would fail. Deterministic id, derived
    from the Cosmos id, gives both properties at once.

    `embedding` is left NULL and is not touched by the upsert: Phase 4a fills it
    via the change feed, and re-running the seed afterwards must not wipe the
    vectors that phase generated.
    """
    doc_id = uuid.uuid5(uuid.NAMESPACE_URL, memory["id"])
    # Read straight through as the ISO string it already is. createdAt is a
    # timestamptz column and Postgres parses ISO 8601 text, so converting to a
    # datetime here would only add a place for the two representations to
    # disagree; now_iso() covers the missing-value case in the same format.
    created_at = memory.get("createdAt") or now_iso()

    conn.execute(
        """
        INSERT INTO documents (
            id, "chronicleId", "contributorId", topic, "createdAt", embedding, metadata
        )
        VALUES (%s::uuid, %s, %s, %s, %s, NULL, %s)
        ON CONFLICT (id) DO UPDATE SET
            "chronicleId"   = EXCLUDED."chronicleId",
            "contributorId" = EXCLUDED."contributorId",
            topic           = EXCLUDED.topic,
            "createdAt"     = EXCLUDED."createdAt",
            metadata        = EXCLUDED.metadata
        """,
        (
            str(doc_id),
            memory.get("chronicleId"),
            memory.get("contributorId"),
            memory.get("topic"),
            created_at,
            Json(memory.get("metadata", {})),
        ),
    )

    conn.commit()


# --- Cosmos -----------------------------------------------------------------

# Partition keys, mirrored from infra/modules/cosmos.bicep (Step 1). Only used on
# the create path, which normally does not run: provision-env.sh creates all nine.
# Kept here so the seed still works against a fresh account, and asserted against
# cosmos.bicep by the drift test so the two cannot diverge.
CONTAINER_PARTITION_KEYS = {
    "households": "/id",
    "chronicles": "/householdId",
    "contributors": "/householdId",
    "invites": "/householdId",
    "prompts": "/chronicleId",
    "memories": "/chronicleId",
    "transcripts": "/chronicleId",
    "flags": "/chronicleId",
    "aliasHistory": "/chronicleId",
}

# The memories vector index, mirrored from cosmos.bicep. Without it a
# freshly-created memories container rejects vector queries, so the create path
# has to carry it rather than only the partition key.
_MEMORIES_INDEXING_POLICY = {
    "indexingMode": "consistent",
    "includedPaths": [{"path": "/*"}],
    "excludedPaths": [{"path": '/"_etag"/?'}, {"path": "/embedding/*"}],
    "vectorEmbeddings": [
        {
            "path": "/embedding",
            "dataType": "float32",
            "distanceFunction": "cosine",
            "dimensions": EMBEDDING_DIMS,
        }
    ],
}


def container(db, name: str):
    """Return a client for container `name`, creating it if it does not exist.

    Creation is a fallback, not the normal path: the nine containers and their
    partition keys are provisioned by infra/modules/cosmos.bicep, so on a healthy
    environment every call here is a lookup. That is deliberate — recreating an
    existing container with different settings silently diverges from the
    deployed indexing policy.

    list_containers() rather than get_container_client(): the latter returns a
    client object eagerly and only fails later, on first use, which would surface
    as a confusing 404 during the seed rather than here.
    """
    partition_key_path = CONTAINER_PARTITION_KEYS.get(name)
    if partition_key_path is None:
        raise KeyError(
            f"unknown container {name!r}; expected one of {sorted(CONTAINER_PARTITION_KEYS)}"
        )

    if name not in {entry["id"] for entry in db.list_containers()}:
        kwargs = {"indexing_policy": _MEMORIES_INDEXING_POLICY} if name == "memories" else {}
        db.create_container_if_not_exists(
            id=name,
            partition_key=PartitionKey(path=partition_key_path),
            **kwargs,
        )

    return db.get_container_client(name)


def upsert(db, container_name: str, doc: dict) -> None:
    """Upsert `doc` into `container_name` keyed on doc["id"].

    Must be an upsert, never create_item: the verify check runs this script
    twice and compares counts, and create_item raises 409 on the second run.

    Routed through container() so the container is resolved (and created if
    missing) in one place rather than at every call site.
    """
    container(db, container_name).upsert_item(body=doc)


def seed_cosmos(db) -> dict:
    """Write the household, chronicles, contributors and one memory.

    Must cover the AGENTS.md domain invariants:
      - households: 1 doc
      - chronicles: CHRONICLE_IDS
      - contributors: membership rows for 2 owners + 1 Full Contributor
        + 1 Observer, each contributor doc carrying BOTH the owner-managed
        fields (contact, relation, status) AND the contributor-managed
        per-chronicle maps displayAlias + promptCadence (one 'weekly',
        one default 'monthly')
      - memories: 1 doc snapshotting contributorId + aliasAtWriteTime, plus
        promptId / parentMemoryId / turnCount / conversationId (schema is
        multi-turn-ready even though the flow is single-shot)

    Schema only — no last-owner enforcement and no Guardian logic (later phases).

    Returns the memory document so main() can mirror it into Postgres without
    rebuilding it (a rebuilt copy could disagree with what was written).
    """
    # One timestamp for the whole seed, and a string rather than a datetime —
    # see now_iso(). Re-running produces a new value, which the upsert then
    # overwrites; that is the intent, not a violation of the idempotency rule
    # (which is about row counts, and what step-5.md verifies).
    now = now_iso()

    upsert(
        db,
        "households",
        {"id": HOUSEHOLD_ID, "name": "Seed Household", "createdAt": now},
    )

    for chronicle_id in CHRONICLE_IDS:
        upsert(
            db,
            "chronicles",
            {
                "id": chronicle_id,
                "householdId": HOUSEHOLD_ID,
                "name": f"Seed Chronicle {chronicle_id[-1]}",
                "createdAt": now,
            },
        )

    contributors = _contributors()
    for contributor in contributors:
        upsert(db, "contributors", {"householdId": HOUSEHOLD_ID, **contributor})

    author = contributors[0]
    memory = {
        "id": MEMORY_ID,
        "householdId": HOUSEHOLD_ID,
        "chronicleId": CHRONICLE_IDS[0],
        "contributorId": author["id"],
        # Frozen copy of the alias in force when this was written, so a later
        # rename cannot retroactively change who a memory appears to be from.
        "aliasAtWriteTime": author["displayAlias"][CHRONICLE_IDS[0]],
        "body": "Grandma's 60th birthday was a surprise party in the garden.",
        "topic": "family-events",
        # Multi-turn-ready schema even though the flow is single-shot: a
        # single-shot turn is turnCount 0 with no parent.
        "promptId": f"prompt-{MEMORY_ID}",
        "parentMemoryId": None,
        "turnCount": 0,
        "conversationId": f"conv-{MEMORY_ID}",
        "createdAt": now,
    }
    upsert(db, "memories", memory)

    return memory


# --- Redis ------------------------------------------------------------------


def seed_redis(conn: redis.Redis) -> None:
    """PING the cache and write the alias-lookup key.

    Phase 2 only proves connectivity and seeds the key shape; TTL-caching
    behaviour arrives in later phases, so no expiry is set here.
    """
    if not conn.ping():
        raise RuntimeError("Redis PING did not return True — cache unreachable?")

    lookup = {contributor["id"]: contributor["displayAlias"] for contributor in _contributors()}
    conn.set(ALIAS_LOOKUP_KEY, json.dumps(lookup))


# --- Entry point ------------------------------------------------------------


def count_items(db, container_name: str) -> int:
    """Return how many items `container_name` holds.

    A COUNT query rather than reading the items: the seed runs against a
    container that may hold real data, and this is only here to print the
    counts step-5.md verifies. The cross-partition flag is required — the
    containers partition on /chronicleId or /householdId, so a plain query would
    only see one partition and undercount.

    `SELECT VALUE COUNT(1)`, with no alias: cross-partition aggregates accept
    only the VALUE form, and `COUNT(1) AS count` is rejected with
    "Cross partition query only supports 'VALUE <AggregateFunc>'". VALUE makes
    each result row the bare number, hence rows[0] rather than rows[0]["count"].

    Note there is no count helper on the SDK's DatabaseProxy; anything named
    like one belongs to the test fake, not to Cosmos.
    """
    rows = list(
        db.get_container_client(container_name).query_items(
            query="SELECT VALUE COUNT(1) FROM c",
            enable_cross_partition_query=True,
        )
    )
    return int(rows[0])


def main() -> None:
    """Run the seed in order: schema, then data, then report counts.

    Order matters: the schema must exist before seed_documents inserts, and
    seed_cosmos runs first so its memory doc is available to mirror into
    Postgres without rebuilding it.

    Counts at the end are the verify evidence for docs/phase-2/step-5.md, so
    print them — but never print a connection string or secret value.
    """
    secrets = resolve_secrets()
    cosmos_client, database_name, _ = resolve_cosmos()
    db = cosmos_client.get_database_client(database_name)

    with psycopg.connect(secrets[SECRET_POSTGRES]) as conn:
        postgres_schema(conn)

        memory = seed_cosmos(db)
        seed_documents(conn, memory)

        # from_url, no parsing: redis.bicep stores a rediss:// URL precisely so
        # every client gets one obvious call. The old Azure key string
        # (host:6380,password=...,ssl=True) is not a URL and needed a parser.
        seed_redis(redis.Redis.from_url(secrets[SECRET_REDIS], decode_responses=True))

        counts = {
            name: count_items(db, name)
            for name in ("households", "chronicles", "contributors", "memories")
        }

    print("Seed complete.")
    for name, count in counts.items():
        print(f"  cosmos {name}: {count}")
    with psycopg.connect(secrets[SECRET_POSTGRES]) as conn:
        row = conn.execute("SELECT count(*) FROM documents").fetchone()
    print(f"  postgres documents: {row[0]}")


if __name__ == "__main__":
    main()
