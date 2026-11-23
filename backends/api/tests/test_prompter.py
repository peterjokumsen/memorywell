from datetime import UTC, datetime, timedelta

from persona import PERSONAS, get_persona
from prompter import (
    PromptContext,
    build_prompt,
    generate_question,
    get_alias,
    is_due,
    snapshot_alias,
)


def test_get_persona_default():
    assert get_persona() == PERSONAS["warm-family"]


def test_get_persona_unknown_falls_back():
    assert get_persona("nope") == PERSONAS["warm-family"]


def test_build_prompt_includes_alias_and_memories():
    ctx = PromptContext(
        chronicle_id="c1",
        contributor_id="u1",
        alias="Granny",
        memories=["First steps", "Birthday"],
    )
    msgs = build_prompt(ctx)
    assert msgs[0]["role"] == "system"
    assert "Granny" in msgs[1]["content"]
    assert "First steps" in msgs[1]["content"]
    assert "Birthday" in msgs[1]["content"]


def test_build_prompt_no_memories():
    ctx = PromptContext(chronicle_id="c1", contributor_id="u1", alias="Gaga")
    msgs = build_prompt(ctx)
    assert "(none)" in msgs[1]["content"]


def test_build_prompt_followup_uses_new_memory():
    ctx = PromptContext(
        chronicle_id="c1",
        contributor_id="u1",
        alias="Granny",
        persona="curious-learner",
        mode="followup",
        new_memory="We went to the lake.",
    )
    msgs = build_prompt(ctx)
    assert "We went to the lake." in msgs[1]["content"]
    assert "digs into a detail" in msgs[1]["content"]


def test_snapshot_alias():
    assert snapshot_alias("Granny") == "Granny"


def test_get_alias_from_dict():
    contrib = {"displayAlias": {"c1": "Gaga", "c2": "Granny"}}
    assert get_alias(contrib, "c1") == "Gaga"
    assert get_alias(contrib, "missing") == "Gaga"


def test_is_due_none_and_special():
    now = datetime.now(UTC)
    assert is_due("none", None, now) is False
    assert is_due("special-occasions", None, now) is False


def test_is_due_weekly():
    now = datetime.now(UTC)
    assert is_due("weekly", None, now) is True
    assert is_due("weekly", now - timedelta(days=8), now) is True
    assert is_due("weekly", now - timedelta(days=3), now) is False


def test_is_due_monthly_calendar():
    now = datetime(2026, 3, 15, tzinfo=UTC)
    last = datetime(2026, 2, 10, tzinfo=UTC)
    assert is_due("monthly", last, now) is True
    last2 = datetime(2026, 2, 20, tzinfo=UTC)
    assert is_due("monthly", last2, now) is False


def test_generate_question_with_llm():
    ctx = PromptContext(chronicle_id="c1", contributor_id="u1", alias="Gaga", memories=["m"])
    q = generate_question(ctx, llm=lambda msgs: "How are you?")
    assert q == "How are you?"
