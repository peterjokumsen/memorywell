from guardian import GuardianScore, build_flag, emit_memory_flagged


def test_build_flag():
    s = GuardianScore(safety=0.9, reasons=["unsafe"])
    f = build_flag("m1", s)
    assert f.memory_id == "m1"
    assert f.status == "open"
    assert "unsafe" in f.reason


def test_emit_memory_flagged():
    s = GuardianScore(safety=0.9, reasons=["unsafe"])
    f = build_flag("m1", s)
    evt = emit_memory_flagged(f)
    assert evt["event"] == "memory.flagged"
    assert evt["memory_id"] == "m1"
