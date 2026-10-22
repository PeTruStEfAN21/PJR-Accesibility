import json
from contextlib import contextmanager

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import create_app


@pytest.fixture
def client():
    return TestClient(create_app(ai_client=None))


def new_code(client: TestClient) -> str:
    response = client.post("/api/sessions")
    assert response.status_code == 201
    return response.json()["code"]


def caption(text: str, speaker: str = "coordinator") -> dict:
    return {
        "type": "caption",
        "id": "c1",
        "speaker": speaker,
        "text": text,
        "final": True,
        "lang": "ro-RO",
        "ts": 1,
    }


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_config_exposes_public_url(monkeypatch):
    monkeypatch.setenv("PUBLIC_URL", "http://172.20.10.2:8000")
    client = TestClient(create_app(ai_client=None))
    assert client.get("/api/config").json() == {"public_url": "http://172.20.10.2:8000"}


def test_unknown_session_is_rejected(client):
    with pytest.raises(WebSocketDisconnect) as exc:
        with client.websocket_connect("/ws/ZZZZZZ?role=participant") as ws:
            ws.receive_json()
    assert exc.value.code == 4404


def test_invalid_role_is_rejected(client):
    code = new_code(client)
    with pytest.raises(WebSocketDisconnect) as exc:
        with client.websocket_connect(f"/ws/{code}?role=admin") as ws:
            ws.receive_json()
    assert exc.value.code == 4400


def test_join_and_peer_events(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
        joined = presenter.receive_json()
        assert joined == {"type": "joined", "code": code, "role": "presenter", "peers": {"presenter": 1}}
        with client.websocket_connect(f"/ws/{code.lower()}?role=participant") as participant:
            assert participant.receive_json()["peers"] == {"presenter": 1, "participant": 1}
            assert presenter.receive_json() == {"type": "peer", "role": "participant", "connected": True}
        assert presenter.receive_json() == {"type": "peer", "role": "participant", "connected": False}


def test_presenter_caption_reaches_participant(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
        presenter.receive_json()
        with client.websocket_connect(f"/ws/{code}?role=participant") as participant:
            participant.receive_json()
            presenter.receive_json()
            presenter.send_json(caption("Bună ziua tuturor"))
            assert participant.receive_json() == caption("Bună ziua tuturor")


def test_participant_notify_reaches_presenter_and_seen_comes_back(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
        presenter.receive_json()
        with client.websocket_connect(f"/ws/{code}?role=participant") as participant:
            participant.receive_json()
            presenter.receive_json()
            notify = {"type": "notify", "id": "n1", "kind": "question", "text": "Am o întrebare", "ts": 2}
            participant.send_json(notify)
            assert presenter.receive_json() == notify
            presenter.send_json({"type": "seen", "id": "n1"})
            assert participant.receive_json() == {"type": "seen", "id": "n1"}


def test_unknown_fields_are_dropped(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
        presenter.receive_json()
        with client.websocket_connect(f"/ws/{code}?role=participant") as participant:
            participant.receive_json()
            presenter.receive_json()
            presenter.send_json({**caption("Salut"), "secret": "x"})
            assert "secret" not in participant.receive_json()


@pytest.mark.parametrize(
    "role,payload",
    [
        ("participant", {"type": "seen", "id": "n1"}),
        ("presenter", {"type": "notify", "id": "n1", "kind": "question", "text": "x", "ts": 1}),
        ("presenter", {"type": "joined"}),
        ("presenter", {"type": "caption", "id": "c1"}),
    ],
)
def test_messages_not_allowed_for_role_return_error(client, role, payload):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role={role}") as ws:
        ws.receive_json()
        ws.send_json(payload)
        assert ws.receive_json()["type"] == "error"


def test_invalid_json_returns_error(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as ws:
        ws.receive_json()
        ws.send_text("not json")
        assert ws.receive_json()["type"] == "error"


def test_oversized_message_returns_error(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as ws:
        ws.receive_json()
        ws.send_text(json.dumps(caption("a" * 5000)))
        assert ws.receive_json()["type"] == "error"


@contextmanager
def connected_pair(client: TestClient):
    """Presenter + participant on a new session, with the join events drained."""
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
        presenter.receive_json()
        with client.websocket_connect(f"/ws/{code}?role=participant") as participant:
            participant.receive_json()
            presenter.receive_json()
            yield presenter, participant


def test_presenter_can_send_read(client):
    with connected_pair(client) as (presenter, participant):
        presenter.send_json({"type": "read", "id": "q1", "by": "voice"})
        assert participant.receive_json() == {"type": "read", "id": "q1", "by": "voice"}


def test_participant_cannot_send_read(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=participant") as participant:
        participant.receive_json()
        participant.send_json({"type": "read", "id": "q1", "by": "voice"})
        assert participant.receive_json() == {"type": "error", "message": "participant cannot send read"}


def test_read_by_must_be_voice_or_speaker(client):
    code = new_code(client)
    with client.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
        presenter.receive_json()
        presenter.send_json({"type": "read", "id": "q1", "by": "robot"})
        assert presenter.receive_json() == {"type": "error", "message": "invalid message"}


def test_hand_notify_with_empty_text_is_relayed(client):
    with connected_pair(client) as (presenter, participant):
        hand = {"type": "notify", "id": "h1", "kind": "hand", "text": "", "ts": 3}
        participant.send_json(hand)
        assert presenter.receive_json() == hand
