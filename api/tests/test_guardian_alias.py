from guardian import apply_alias, validate_alias


def test_validate_alias_ok():
    ok, reason = validate_alias("Granny", {"Mom"}, None)
    assert ok is True


def test_validate_alias_duplicate():
    ok, reason = validate_alias("Mom", {"Mom"}, None)
    assert ok is False


def test_apply_alias():
    r = apply_alias("c1", "Granny")
    assert r["event"] == "alias.updated"
    assert r["display_alias"] == "Granny"
