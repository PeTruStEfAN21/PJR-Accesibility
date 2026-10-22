import asyncio

import pytest
from fastapi.testclient import TestClient

from app import ai
from app.main import create_app
from app.schemas import Line
from tests.fakes import FakeAnthropic, json_response, text_response

LINES = [
    Line(id=1, speaker="coordinator", text="Bun venit la ședință"),
    Line(id=2, speaker="public", text="Când e termenul pentru raport?"),
]


def run(coro):
    return asyncio.run(coro)


def test_summarize_parses_structured_output_and_uses_fallbacks():
    fake = FakeAnthropic(json_response({"summary": "Ședință scurtă.", "tasks": [{"text": "Raportul", "owner": None}]}))
    result = run(ai.summarize(fake, "ro", LINES))

    assert result.summary == "Ședință scurtă."
    assert result.tasks[0].text == "Raportul"
    call = fake.calls[0]
    assert call["model"] == "claude-opus-5-5"
    assert call["fallbacks"] == "default"
    assert call["betas"] == ["server-side-fallback-2026-07-01"]
    assert call["output_config"]["effort"] == "medium"
    assert call["output_config"]["format"]["type"] == "json_schema"
    assert "Romanian" in call["system"]
    assert "[#2] Audience: Când e termenul pentru raport?" in call["messages"][0]["content"]


def test_unknown_language_code_is_passed_through_by_code():
    fake = FakeAnthropic(json_response({"summary": "x", "tasks": []}))
    run(ai.summarize(fake, "de", LINES))
    assert "de" in fake.calls[0]["system"]


def test_refusal_raises():
    fake = FakeAnthropic(text_response("", stop_reason="refusal"))
    with pytest.raises(ai.AIRefused):
        run(ai.summarize(fake, "ro", LINES))


def test_simplify_returns_text_with_low_effort():
    fake = FakeAnthropic(text_response("Termenul e vineri."))
    assert run(ai.simplify(fake, "ro", "Termenul limită a fost stabilit pentru vineri.")) == "Termenul e vineri."
    assert fake.calls[0]["output_config"] == {"effort": "low"}


def test_ai_endpoints_return_503_without_key():
    client = TestClient(create_app(ai_client=None))
    response = client.post("/api/ai/simplify", json={"lang": "ro", "text": "Salut"})
    assert response.status_code == 503


def test_summary_endpoint():
    fake = FakeAnthropic(json_response({"summary": "Rezumat", "tasks": []}))
    client = TestClient(create_app(ai_client=fake))
    response = client.post(
        "/api/ai/summary",
        json={"lang": "en", "lines": [{"id": 1, "speaker": "coordinator", "text": "Hello"}]},
    )
    assert response.status_code == 200
    assert response.json() == {"summary": "Rezumat", "tasks": []}


def test_refusal_maps_to_422():
    client = TestClient(create_app(ai_client=FakeAnthropic(text_response("", stop_reason="refusal"))))
    response = client.post("/api/ai/simplify", json={"lang": "ro", "text": "Salut"})
    assert response.status_code == 422


@pytest.mark.parametrize("lang", ["", "romana", "RO", "r1"])
def test_invalid_language_is_rejected(lang):
    client = TestClient(create_app(ai_client=FakeAnthropic()))
    assert client.post("/api/ai/simplify", json={"lang": lang, "text": "Salut"}).status_code == 422
