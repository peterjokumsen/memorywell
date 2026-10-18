"""Read-only verification of the Phase 2 seed, against the live stores.

Covers the Verify checklist in docs/phase-2/step-5.md, which is otherwise a list
of things to go and look at. Run it through scripts/verify-seed.sh, which
sources common.sh first:

    ./scripts/verify-seed.sh

Read-only: it reads the seeded documents, PINGs Redis and selects from
`documents`. It never writes, so it is safe to run against a live environment
and cannot be the thing that broke the seed it is checking.

Prints no secret values. Connection strings come from Key Vault through the same
resolve_secrets() the seed uses and go straight into the clients; only derived
facts (counts, column names, PING) reach stdout.

Nothing here runs in CI. It needs live Azure resources, which are not free, so
like every manual check in the phase briefs it stays out of pytest; the pure
tests in scripts/tests/ cover the parts that can be.
"""

from __future__ import annotations

import json
import sys
import uuid

import psycopg
import redis as redis_lib
import seed

# The column list step-2.md specifies, in order, as information_schema reports
# it. Postgres preserves the case of quoted identifiers, so "chronicleId" comes
# back camelCase — and an unquoted CREATE TABLE would have produced "chronicleid",
# which is the failure the quoting exists to prevent.
EXPECTED_COLUMNS = [
    ("id", "uuid"),
    ("chronicleId", "text"),
    ("contributorId", "text"),
    ("topic", "text"),
    ("createdAt", "timestamp with time zone"),
    ("embedding", "USER-DEFINED"),
    ("metadata", "jsonb"),
]

# PLAN.md:63 — none | special-occasions | monthly | weekly.
VALID_CADENCES = {"none", "special-occasions", "monthly", "weekly"}

MULTI_TURN_FIELDS = ("promptId", "parentMemoryId", "turnCount", "conversationId")
OWNER_MANAGED_FIELDS = ("contact", "relation", "status")

_failures = 0


def ok(message: str) -> None:
    print(f"  ok    {message}")


def bad(message: str) -> None:
    global _failures
    _failures += 1
    print(f"  FAIL  {message}")


def check(description: str, condition: bool, detail: str = "") -> None:
    """Report one assertion. `detail` explains a failure, not a pass."""
    if condition:
        ok(description)
    else:
        bad(f"{description}{f' — {detail}' if detail else ''}")


def section(title: str) -> None:
    print(f"\n{title}")


def fetch_one(db, container_name: str, doc_id: str, partition_key: str) -> dict:
    """Read one item by id.

    `partition_key` is not optional decoration: memories partitions on
    /chronicleId and contributors on /householdId, so a query without it is
    rejected with "Cross partition query is required but disabled".
    """
    items = db.get_container_client(container_name).query_items(
        query="SELECT * FROM c WHERE c.id = @id",
        parameters=[{"name": "@id", "value": doc_id}],
        partition_key=partition_key,
    )
    return next(iter(items), {})


# --- Cosmos ------------------------------------------------------------------


def verify_cosmos(db) -> None:
    section("Cosmos")

    memory = fetch_one(db, "memories", seed.MEMORY_ID, seed.CHRONICLE_IDS[0])
    check(
        f"memory {seed.MEMORY_ID} exists",
        bool(memory),
        "run scripts/seed.py first",
    )
    check(
        "memory snapshots aliasAtWriteTime",
        bool(memory.get("aliasAtWriteTime")),
        f"aliasAtWriteTime={memory.get('aliasAtWriteTime')!r}",
    )
    missing = [field for field in MULTI_TURN_FIELDS if field not in memory]
    check(
        "memory is multi-turn-ready (AGENTS.md)",
        not missing,
        f"missing {missing}",
    )

    contributor = fetch_one(db, "contributors", "contrib-seed-1", seed.HOUSEHOLD_ID)
    missing = [field for field in OWNER_MANAGED_FIELDS if field not in contributor]
    check("contributor carries owner-managed fields", not missing, f"missing {missing}")
    for field in ("displayAlias", "promptCadence"):
        check(f"contributor carries the {field} map", bool(contributor.get(field)))

    bad_cadences = {
        cadence
        for doc in db.get_container_client("contributors").read_all_items()
        for cadence in doc.get("promptCadence", {}).values()
        if cadence not in VALID_CADENCES
    }
    check(
        "every promptCadence is a PLAN.md enum value",
        not bad_cadences,
        f"unexpected {sorted(bad_cadences)}",
    )

    counts = {
        name: seed.count_items(db, name)
        for name in ("households", "chronicles", "contributors", "memories")
    }
    expected = {
        "households": 1,
        "chronicles": len(seed.CHRONICLE_IDS),
        "contributors": 4,
        "memories": 1,
    }
    check(
        f"seeded counts {counts}",
        counts == expected,
        f"expected {expected}",
    )
    print(
        "  note  counts match a fresh seed; to prove idempotency, run the seed "
        "twice more and\n        compare — this script only reads."
    )


# --- Redis -------------------------------------------------------------------


def verify_redis(url: str, expected_contributors: int) -> None:
    section("Redis")
    client = redis_lib.Redis.from_url(url, decode_responses=True)
    check("PING returns PONG", client.ping() is True)
    lookup = client.get(seed.ALIAS_LOOKUP_KEY)
    check(
        f"alias-lookup key {seed.ALIAS_LOOKUP_KEY} is set",
        bool(lookup),
        "seed_redis writes it",
    )
    aliases = json.loads(lookup) if lookup else {}
    check(
        "alias-lookup covers every contributor",
        bool(aliases) and len(aliases) == expected_contributors,
        f"{len(aliases)} of {expected_contributors}",
    )


# --- Postgres ----------------------------------------------------------------


def verify_postgres(url: str) -> None:
    section("Postgres")
    with psycopg.connect(url) as conn:
        columns = conn.execute(
            "SELECT column_name, data_type FROM information_schema.columns "
            "WHERE table_name = 'documents' ORDER BY ordinal_position"
        ).fetchall()
        check(
            f"\\d documents matches step-2.md ({len(EXPECTED_COLUMNS)} columns)",
            [tuple(row) for row in columns] == EXPECTED_COLUMNS,
            f"got {[tuple(row) for row in columns]}",
        )

        udt = conn.execute(
            "SELECT udt_name FROM information_schema.columns "
            "WHERE table_name = 'documents' AND column_name = 'embedding'"
        ).fetchone()
        check(
            f"embedding is vector({seed.EMBEDDING_DIMS})",
            udt is not None and udt[0] == "vector",
            f"udt_name={udt[0] if udt else None!r}",
        )

        extensions = {row[0] for row in conn.execute("SELECT extname FROM pg_extension")}
        check(
            "vector extension still installed (step-2.md allowlist not regressed)",
            "vector" in extensions,
            f"extensions={sorted(extensions)}",
        )

        row = conn.execute(
            'SELECT id, "chronicleId", "contributorId", "createdAt" FROM documents'
        ).fetchone()
        check("one row mirrors the Cosmos memory", row is not None)
        if row is not None:
            expected_id = uuid.uuid5(uuid.NAMESPACE_URL, seed.MEMORY_ID)
            check(
                "documents.id is uuid5(NAMESPACE_URL, cosmos id)",
                row[0] == expected_id,
                "a uuid4 here means the upsert never fires and every run appends",
            )
            check("mirrors the memory's chronicleId", row[1] == seed.CHRONICLE_IDS[0])


def main() -> int:
    print("Phase 2 seed verification (read-only)")
    client, database_name, _ = seed.resolve_cosmos()
    db = client.get_database_client(database_name)
    secrets = seed.resolve_secrets()

    verify_cosmos(db)
    verify_redis(secrets[seed.SECRET_REDIS], seed.count_items(db, "contributors"))
    verify_postgres(secrets[seed.SECRET_POSTGRES])

    print()
    if _failures:
        print(f"{_failures} check(s) FAILED.")
        return 1
    print("All checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
