"""Tests for scripts/verify_seed.py — the manual Phase 2 verification script.

verify_seed.py checks live Azure resources, so none of its checks can run here;
they stay in docs/phase-2/step-5.md's Verify list and in the script itself. What
is testable is everything around them: that a failing check is reported and
counted rather than passing quietly, and that the schema it expects is the
schema seed.py actually creates. Without the second one, editing the DDL and
forgetting the verifier's copy would leave a green script checking a table
nobody creates.
"""

import pytest
import seed
import verify_seed
from fakes import FakeSqlConn


@pytest.fixture(autouse=True)
def reset_failures():
    """_failures is module-level state; keep one test's failures out of the next."""
    before = verify_seed._failures
    yield
    verify_seed._failures = before


# --- reporting ---------------------------------------------------------------


def test_passing_check_is_reported_ok(capsys):
    verify_seed.check("a thing is true", True)

    out = capsys.readouterr().out
    assert "ok    a thing is true" in out
    assert "FAIL" not in out


def test_failing_check_is_reported_and_counted(capsys):
    """A verifier that cannot fail is worse than none: it reads as a pass."""
    verify_seed.check("a thing is true", False, "it is not")

    out = capsys.readouterr().out
    assert "FAIL  a thing is true — it is not" in out
    assert verify_seed._failures == 1


def test_detail_is_shown_on_failure_not_on_pass(capsys):
    """Detail explains a failure. Printing it on a pass turns the output into
    noise and, worse, invites copying explanations of things that are fine."""
    verify_seed.check("passes", True, "nothing to explain")

    assert "nothing to explain" not in capsys.readouterr().out


# --- expected schema ---------------------------------------------------------


def _ddl_column_names() -> list[str]:
    """Column names, in order, from the CREATE TABLE seed.py executes.

    Parsed rather than restated: step-2.md owns the schema, seed.py implements
    it, and this is how the verifier's own expectation is held to that
    implementation instead of to a third copy of the same list.
    """
    conn = FakeSqlConn()
    seed.postgres_schema(conn)

    lines = conn.sql.splitlines()
    start = next(i for i, line in enumerate(lines) if "CREATE TABLE" in line)
    names = []
    for line in lines[start + 1 :]:
        stripped = line.strip()
        if stripped.startswith(")"):
            break
        if stripped:
            names.append(stripped.split()[0].strip('"'))
    return names


def test_expected_columns_match_the_ddl_seed_creates():
    """verify_seed.EXPECTED_COLUMNS must equal the table seed.py builds.

    A column added to the DDL without updating the verifier would otherwise
    keep reporting a seven-column match against an eight-column table — the
    check would go on passing while inspecting a table that no longer exists in
    that shape.
    """
    assert _ddl_column_names() == [name for name, _ in verify_seed.EXPECTED_COLUMNS]


def test_expected_columns_are_the_documented_seven():
    """The list is step-2.md's schema, verbatim and in order: id, chronicleId,
    contributorId, topic, createdAt, embedding, metadata."""
    assert [name for name, _ in verify_seed.EXPECTED_COLUMNS] == [
        "id",
        "chronicleId",
        "contributorId",
        "topic",
        "createdAt",
        "embedding",
        "metadata",
    ]
