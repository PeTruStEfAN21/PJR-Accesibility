"""Sessions and limits shared through Redis, as when several server instances run."""

import asyncio

import pytest
from fastapi.testclient import TestClient

fakeredis = pytest.importorskip("fakeredis")

from app.hub import RedisHub  # noqa: E402
from app.limits import RedisLimiter  # noqa: E402
from app.main import create_app  # noqa: E402


def caption(text: str) -> dict:
    return {"type": "caption", "id": "c1", "speaker": "coordinator", "text": text, "final": True, "lang": "ro-RO", "ts": 1}


@pytest.fixture
def server():
    return fakeredis.FakeServer()


def instance(server) -> TestClient:
    redis = fakeredis.FakeAsyncRedis(server=server, decode_responses=True)
    return TestClient(create_app(ai_client=None, hub=RedisHub(redis), limiter=RedisLimiter(redis), verifier=None))


def receive_skipping_peers(ws) -> dict:
    while (message := ws.receive_json())["type"] == "peer":
        pass
    return message


def test_presenter_and_participant_on_different_instances(server):
    with instance(server) as a, instance(server) as b:
        code = a.post("/api/sessions").json()["code"]
        with a.websocket_connect(f"/ws/{code}?role=presenter") as presenter:
            presenter.receive_json()
            with b.websocket_connect(f"/ws/{code.lower()}?role=participant") as participant:
                joined = participant.receive_json()
                assert joined["code"] == code
                assert joined["peers"] == {"presenter": 1, "participant": 1}
                assert presenter.receive_json() == {"type": "peer", "role": "participant", "connected": True}

                presenter.send_json(caption("Bună ziua"))
                assert receive_skipping_peers(participant) == caption("Bună ziua")

                notify = {"type": "notify", "id": "n1", "kind": "question", "text": "Am o întrebare", "ts": 2}
                participant.send_json(notify)
                assert presenter.receive_json() == notify
            assert presenter.receive_json() == {"type": "peer", "role": "participant", "connected": False}


def test_sender_does_not_get_its_own_message(server):
    with instance(server) as a:
        code = a.post("/api/sessions").json()["code"]
        with a.websocket_connect(f"/ws/{code}?role=presenter") as p1, a.websocket_connect(f"/ws/{code}?role=participant") as p2:
            p1.receive_json()
            p2.receive_json()
            p1.receive_json()  # p2 connected
            p1.send_json(caption("unu"))
            assert receive_skipping_peers(p2) == caption("unu")
            p2.send_json(caption("doi"))
            # p1 gets p2's caption next, not an echo of its own.
            assert receive_skipping_peers(p1) == caption("doi")


def test_unknown_session_is_rejected(server):
    from starlette.websockets import WebSocketDisconnect

    with instance(server) as a:
        with pytest.raises(WebSocketDisconnect) as exc:
            with a.websocket_connect("/ws/ZZZZZZ?role=participant") as ws:
                ws.receive_json()
        assert exc.value.code == 4404


def test_sessions_expire_in_redis(server):
    async def scenario():
        redis = fakeredis.FakeAsyncRedis(server=server, decode_responses=True)
        hub = RedisHub(redis, ttl_seconds=60)
        code = await hub.create()
        assert 0 < await redis.ttl(f"echo:session:{code}") <= 60
        await redis.delete(f"echo:session:{code}")
        assert await hub.join(code, object(), "participant") is None

    asyncio.run(scenario())


def test_redis_limiter_counts_across_instances(server):
    async def scenario():
        first = RedisLimiter(fakeredis.FakeAsyncRedis(server=server, decode_responses=True))
        second = RedisLimiter(fakeredis.FakeAsyncRedis(server=server, decode_responses=True))
        assert await first.hit("ip:1", 2) is None
        assert await second.hit("ip:1", 2) is None
        retry = await first.hit("ip:1", 2)
        assert retry is not None and 0 < retry <= 3600

    asyncio.run(scenario())
