import asyncio

from fastapi.testclient import TestClient

from app import agent
from app.main import create_app
from app.schemas import Line
from tests.fakes import FakeAnthropic, text_response, tool_use_response

LINES = [
    Line(id=1, speaker="coordinator", text="Bun venit la întâlnirea de azi"),
    Line(id=2, speaker="coordinator", text="Raportul trebuie trimis până vineri"),
    Line(id=3, speaker="public", text="Cine se ocupă de buget?"),
]


def run(coro):
    return asyncio.run(coro)


def test_search_ignores_case_and_diacritics():
    result = agent.search_transcript(LINES, "INTALNIRE", "any")
    assert "[#1]" in result
    assert "[#2]" not in result


def test_search_filters_by_speaker():
    result = agent.search_transcript(LINES, "buget raportul", "public")
    assert "[#3]" in result
    assert "[#2]" not in result


def test_search_without_matches_says_so():
    assert "No lines" in agent.search_transcript(LINES, "pizza", "any")


def test_read_lines_clamps_range():
    result = agent.read_lines(LINES, 2, 99)
    assert result.splitlines() == [
        "[#2] Coordinator: Raportul trebuie trimis până vineri",
        "[#3] Audience: Cine se ocupă de buget?",
    ]


def test_ask_runs_tools_and_returns_valid_citations():
    fake = FakeAnthropic(
        tool_use_response(("t1", "search_transcript", {"query": "raport", "speaker": "any"})),
        text_response("Raportul se trimite până vineri [#2]. Vezi și [#99]."),
    )
    result = run(agent.ask(fake, "ro", LINES, "Până când trimit raportul?"))

    assert result.citations == [2]
    assert "vineri" in result.answer
    second = fake.calls[1]["messages"]
    assert second[1]["role"] == "assistant"
    tool_result = second[2]["content"][0]
    assert tool_result["tool_use_id"] == "t1"
    assert "[#2]" in tool_result["content"]
    assert {tool["name"] for tool in fake.calls[0]["tools"]} == {"search_transcript", "read_lines"}
    assert all(tool["strict"] for tool in fake.calls[0]["tools"])


def test_unknown_tool_returns_error_result():
    fake = FakeAnthropic(
        tool_use_response(("t1", "delete_everything", {})),
        text_response("Nu am găsit."),
    )
    run(agent.ask(fake, "ro", LINES, "?"))
    tool_result = fake.calls[1]["messages"][2]["content"][0]
    assert tool_result["is_error"] is True


def test_last_step_forbids_tools_so_the_agent_must_answer():
    search = ("t", "search_transcript", {"query": "x", "speaker": "any"})
    responses = [tool_use_response(search) for _ in range(agent.MAX_STEPS - 1)]
    fake = FakeAnthropic(*responses, text_response("Nu apare în transcriere."))
    result = run(agent.ask(fake, "ro", LINES, "Ce culoare are logo-ul?"))

    assert len(fake.calls) == agent.MAX_STEPS
    assert fake.calls[-1]["tool_choice"] == {"type": "none"}
    assert result.citations == []


def test_ask_endpoint():
    fake = FakeAnthropic(text_response("Bugetul nu a fost atribuit [#3]."))
    client = TestClient(create_app(ai_client=fake))
    response = client.post(
        "/api/ai/ask",
        json={
            "lang": "ro",
            "question": "Cine face bugetul?",
            "lines": [line.model_dump() for line in LINES],
        },
    )
    assert response.status_code == 200
    assert response.json() == {"answer": "Bugetul nu a fost atribuit [#3].", "citations": [3]}
