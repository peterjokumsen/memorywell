from unittest.mock import patch

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_prompts_endpoint():
    with patch("main.generate_question", return_value="How are you?"):
        resp = client.post(
            "/prompts",
            json={
                "chronicle_id": "c1",
                "contributor_id": "u1",
                "alias": "Gaga",
                "memories": ["m1"],
            },
        )
    assert resp.status_code == 200
    assert resp.json() == {"question": "How are you?"}
