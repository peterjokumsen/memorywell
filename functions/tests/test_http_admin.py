import json

import azure.functions as func
from http_admin import http_chronicles, http_households


def _req(method="GET", params=None, body=None):
    return func.HttpRequest(
        method=method,
        url="/",
        params=params or {},
        body=json.dumps(body).encode() if body else b"",
    )


def test_households_get_without_cosmos(monkeypatch):
    import http_admin

    monkeypatch.setattr(http_admin, "_db", lambda: None)
    res = http_households(_req("GET"))
    assert res.status_code == 503


def test_chronicle_missing_params(monkeypatch):
    import http_admin

    monkeypatch.setattr(http_admin, "_db", lambda: None)
    res = http_chronicles(_req("GET", params={}))
    assert res.status_code == 503
