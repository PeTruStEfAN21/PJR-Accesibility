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


ANSWER_LINES = [
    Line(id=2, speaker="coordinator", text="Întrebarea este când e termenul pentru raport"),
    Line(id=3, speaker="coordinator", text="Termenul e vineri la prânz"),
]


def test_check_answer_uses_low_effort_and_schema():
    fake = FakeAnthropic(json_response({"answered": True, "answer": "Vineri la prânz.", "line_ids": [3]}))
    result = run(ai.check_answer(fake, "ro", "Când e termenul?", ANSWER_LINES))

    assert result.answered is True
    assert result.answer == "Vineri la prânz."
    assert result.line_ids == [3]
    call = fake.calls[0]
    assert call["model"] == "claude-opus-5-5"
    assert call["fallbacks"] == "default"
    assert call["output_config"]["effort"] == "low"
    assert call["output_config"]["format"]["type"] == "json_schema"
    content = call["messages"][0]["content"]
    assert "Când e termenul?" in content
    assert "[#3] Coordinator: Termenul e vineri la prânz" in content


def test_check_answer_drops_unknown_line_ids():
    fake = FakeAnthropic(json_response({"answered": True, "answer": "Vineri.", "line_ids": [3, 99]}))
    assert run(ai.check_answer(fake, "ro", "Când?", ANSWER_LINES)).line_ids == [3]


def test_check_answer_refusal_raises():
    fake = FakeAnthropic(text_response("", stop_reason="refusal"))
    with pytest.raises(ai.AIRefused):
        run(ai.check_answer(fake, "ro", "Când?", ANSWER_LINES))


def test_find_questions_returns_ids_in_request():
    fake = FakeAnthropic(json_response({"question_ids": [2, 7]}))
    assert run(ai.find_questions(fake, "ro", LINES)) == [2]
    call = fake.calls[0]
    assert call["output_config"]["effort"] == "low"
    assert "[#2] Audience: Când e termenul pentru raport?" in call["messages"][0]["content"]


def test_answer_check_endpoint():
    fake = FakeAnthropic(json_response({"answered": False, "answer": "", "line_ids": []}))
    client = TestClient(create_app(ai_client=fake))
    response = client.post(
        "/api/ai/answer-check",
        json={"lang": "ro", "question": "Când?", "lines": [{"id": 1, "speaker": "coordinator", "text": "Bun"}]},
    )
    assert response.status_code == 200
    assert response.json() == {"answered": False, "answer": "", "line_ids": []}


def test_questions_endpoint():
    fake = FakeAnthropic(json_response({"question_ids": [1]}))
    client = TestClient(create_app(ai_client=fake))
    response = client.post("/api/ai/questions", json={"lang": "ro", "lines": [{"id": 1, "speaker": "public", "text": "când"}]})
    assert response.status_code == 200
    assert response.json() == {"question_ids": [1]}


@pytest.mark.parametrize(
    "path,body",
    [
        ("/api/ai/answer-check", {"lang": "ro", "question": "Când?", "lines": [{"id": 1, "speaker": "public", "text": "x"}]}),
        ("/api/ai/questions", {"lang": "ro", "lines": [{"id": 1, "speaker": "public", "text": "x"}]}),
    ],
)
def test_new_ai_endpoints_return_503_without_key(path, body):
    client = TestClient(create_app(ai_client=None))
    assert client.post(path, json=body).status_code == 503


def test_answer_check_refusal_maps_to_422():
    client = TestClient(create_app(ai_client=FakeAnthropic(text_response("", stop_reason="refusal"))))
    response = client.post(
        "/api/ai/answer-check",
        json={"lang": "ro", "question": "Când?", "lines": [{"id": 1, "speaker": "public", "text": "x"}]},
    )
    assert response.status_code == 422


def test_questions_accepts_at_most_twenty_lines():
    client = TestClient(create_app(ai_client=FakeAnthropic()))
    lines = [{"id": i, "speaker": "public", "text": "x"} for i in range(1, 22)]
    assert client.post("/api/ai/questions", json={"lang": "ro", "lines": lines}).status_code == 422
