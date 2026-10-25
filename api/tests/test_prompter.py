from persona import PERSONAS, get_persona
from prompter import PromptContext, build_prompt


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
