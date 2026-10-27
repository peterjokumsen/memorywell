from guardian import score_memory


def test_guardian_score_flagged():
    def llm(messages):
        return {
            "safety": 0.9,
            "sensitivity": 0.1,
            "quality": 0.9,
            "duplicate": 0.0,
            "reasons": ["unsafe"],
        }

    s = score_memory("bad", llm=llm)
    assert s.flagged is True
    assert "unsafe" in s.reasons


def test_guardian_score_clean():
    def llm(messages):
        return {
            "safety": 0.1,
            "sensitivity": 0.1,
            "quality": 0.9,
            "duplicate": 0.1,
            "reasons": [],
        }

    s = score_memory("nice memory", llm=llm)
    assert s.flagged is False
