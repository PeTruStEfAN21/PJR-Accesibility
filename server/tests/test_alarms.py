import asyncio
import time

import jwt
from fastapi.testclient import TestClient

from app.auth import Identity, TokenVerifier
from app.main import create_app
from tests.fakes import FakeAnthropic, text_response
from tests.test_accounts import SECRET


def token(sub: str = "user-1", email: str | None = None) -> str:
    claims = {"sub": sub, "aud": "authenticated", "exp": int(time.time()) + 3600}
    if email:
        claims["email"] = email
    return jwt.encode(claims, SECRET, algorithm="HS256")


def test_identity_reads_the_email():
    verifier = TokenVerifier(secret=SECRET)
    assert asyncio.run(verifier.identity(token(email="ana@firma.ro"))) == Identity("user-1", "ana@firma.ro")


def test_raising_an_alarm_needs_an_account():
    client = TestClient(create_app(ai_client=FakeAnthropic(), verifier=TokenVerifier(secret=SECRET)))
    response = client.post("/api/alarms")
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_alarms_need_accounts_configured():
    client = TestClient(create_app(ai_client=None, verifier=None))
    assert client.post("/api/alarms", headers={"Authorization": f"Bearer {token()}"}).status_code == 503


# --- alarm feed ---

import pytest  # noqa: E402

from app.alarms import ACTIVE_SECONDS, Alarm, LocalAlarmFeed, RedisAlarmFeed  # noqa: E402

fakeredis = pytest.importorskip("fakeredis")


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def make_alarm(at: float = 1000.0) -> Alarm:
    return Alarm(id="a1", kind="fire", at=at, lat=44.4, lon=26.1, accuracy_m=12.0)


async def settle(sent: list, count: int) -> None:
    for _ in range(100):
        if len(sent) >= count:
            return
        await asyncio.sleep(0.02)


def feed_scenario(scenario):
    """Runs scenario(feed, sent, clock) against both feeds."""

    @pytest.mark.parametrize("kind", ["local", "redis"])
    def runner(kind):
        async def go():
            sent: list = []
            clock = Clock()

            async def send(socket, payload):
                sent.append((socket, payload))

            if kind == "local":
                feed = LocalAlarmFeed(send=send, clock=clock)
            else:
                redis = fakeredis.FakeAsyncRedis(decode_responses=True)
                feed = RedisAlarmFeed(redis, send=send, clock=clock)
            await feed.start()
            try:
                await scenario(feed, sent, clock)
            finally:
                await feed.close()

        asyncio.run(go())

    runner.__name__ = scenario.__name__
    return runner


@feed_scenario
async def test_new_alarm_reaches_subscribers(feed, sent, clock):
    socket = object()
    feed.subscribe(socket)
    alarm = make_alarm()
    await feed.add(alarm, "u1")
    await settle(sent, 1)
    assert sent == [(socket, alarm.public())]


@feed_scenario
async def test_cancel_by_someone_else_is_forbidden(feed, sent, clock):
    socket = object()
    feed.subscribe(socket)
    alarm = make_alarm()
    await feed.add(alarm, "u1")
    await settle(sent, 1)
    sent.clear()
    assert await feed.cancel(alarm.id, "u2") == "forbidden"
    await asyncio.sleep(0.2)
    assert sent == []
    assert [a.id for a in await feed.active(clock())] == [alarm.id]


@feed_scenario
async def test_cancel_by_owner_reaches_subscribers(feed, sent, clock):
    socket = object()
    feed.subscribe(socket)
    alarm = make_alarm()
    await feed.add(alarm, "u1")
    await settle(sent, 1)
    sent.clear()
    assert await feed.cancel(alarm.id, "u1") == "ok"
    await settle(sent, 1)
    assert sent == [(socket, {"type": "alarm_cancelled", "id": alarm.id})]
    assert await feed.active(clock()) == []


@feed_scenario
async def test_unknown_alarm_is_missing(feed, sent, clock):
    assert await feed.cancel("nope", "u1") == "missing"


@feed_scenario
async def test_alarms_stop_being_active_after_15_minutes(feed, sent, clock):
    await feed.add(make_alarm(at=clock()), "u1")
    clock.now += ACTIVE_SECONDS - 1
    assert len(await feed.active(clock())) == 1
    clock.now += 2
    assert await feed.active(clock()) == []


@feed_scenario
async def test_unsubscribed_socket_gets_nothing(feed, sent, clock):
    socket = object()
    feed.subscribe(socket)
    feed.unsubscribe(socket)
    await feed.add(make_alarm(), "u1")
    await asyncio.sleep(0.2)
    assert sent == []


@feed_scenario
async def test_owner_socket_gets_neither_live_nor_active_alarm(feed, sent, clock):
    mine, theirs = object(), object()
    feed.subscribe(mine, "u1")
    feed.subscribe(theirs, "u2")
    alarm = make_alarm()
    await feed.add(alarm, "u1")
    await settle(sent, 1)
    await asyncio.sleep(0.1)
    assert sent == [(theirs, alarm.public())]
    assert await feed.active(clock(), viewer="u1") == []
    assert [a.id for a in await feed.active(clock(), viewer="u2")] == [alarm.id]
    sent.clear()
    assert await feed.cancel(alarm.id, "u1") == "ok"
    await settle(sent, 2)
    assert {s for s, _ in sent} == {mine, theirs}


@feed_scenario
async def test_redis_envelope_owner_never_reaches_sockets(feed, sent, clock):
    socket = object()
    feed.subscribe(socket, "u2")
    await feed.add(make_alarm(), "u1")
    await settle(sent, 1)
    assert not {"owner", "user_id", "email", "ip", "payload"} & set(sent[0][1])


def test_public_message_has_no_identity():
    keys = set(make_alarm().public())
    assert keys == {"type", "id", "kind", "at", "lat", "lon", "accuracy_m"}
    assert not keys & {"user_id", "email", "ip", "owner"}


# --- alarm routes ---

from starlette.websockets import WebSocketDisconnect  # noqa: E402

FIRE = {"kind": "fire", "lat": 44.43, "lon": 26.10, "accuracy_m": 12}


class FakeRecorder:
    def __init__(self) -> None:
        self.entries: list[dict] = []

    async def record(self, entry: dict) -> None:
        self.entries.append(entry)


def bearer(sub: str = "user-1", email: str | None = "ana@firma.ro") -> dict:
    return {"Authorization": f"Bearer {token(sub, email)}"}


def alarm_app(**kwargs):
    recorder = FakeRecorder()
    app = create_app(ai_client=FakeAnthropic(text_response("ok")), verifier=TokenVerifier(secret=SECRET), recorder=recorder, **kwargs)
    return TestClient(app), recorder


def listen(client: TestClient, sub: str = "user-1"):
    ws = client.websocket_connect("/ws/alarms")
    socket = ws.__enter__()
    socket.send_json({"type": "auth", "token": token(sub)})
    assert socket.receive_json() == {"type": "auth_ok"}
    return ws, socket


def test_alarm_reaches_a_listening_phone():
    client, _ = alarm_app()
    with client:
        ws, socket = listen(client, "user-2")
        try:
            response = client.post("/api/alarms", json=FIRE, headers=bearer())
            assert response.status_code == 201
            message = socket.receive_json()
            assert message["type"] == "alarm" and message["kind"] == "fire"
            assert message["id"] == response.json()["id"]
            assert not {"owner", "user_id", "email", "ip"} & set(message)
        finally:
            ws.__exit__(None, None, None)


def test_alarm_is_recorded_with_the_account():
    client, recorder = alarm_app()
    with client:
        client.post("/api/alarms", json=FIRE, headers=bearer())
    entry = recorder.entries[0]
    assert entry["event"] == "raised"
    assert entry["user_id"] == "user-1" and entry["email"] == "ana@firma.ro"
    assert entry["ip"] and entry["kind"] == "fire"


def test_unknown_kind_is_rejected():
    client, _ = alarm_app()
    with client:
        assert client.post("/api/alarms", json={**FIRE, "kind": "flood"}, headers=bearer()).status_code == 422
        assert client.post("/api/alarms", json={**FIRE, "lat": 91}, headers=bearer()).status_code == 422


def test_only_the_author_can_cancel():
    client, recorder = alarm_app()
    with client:
        ws, socket = listen(client, "user-2")
        try:
            alarm_id = client.post("/api/alarms", json=FIRE, headers=bearer()).json()["id"]
            socket.receive_json()
            assert client.post(f"/api/alarms/{alarm_id}/cancel", headers=bearer("user-2")).status_code == 403
            assert client.post("/api/alarms/nope/cancel", headers=bearer()).status_code == 404
            response = client.post(f"/api/alarms/{alarm_id}/cancel", headers=bearer())
            assert response.status_code == 200 and response.json() == {"id": alarm_id}
            assert socket.receive_json() == {"type": "alarm_cancelled", "id": alarm_id}
        finally:
            ws.__exit__(None, None, None)
    entry = recorder.entries[-1]
    assert entry["event"] == "cancelled" and entry["id"] == alarm_id
    assert entry["user_id"] == "user-1" and entry["kind"] == "fire"


def test_new_listener_gets_active_alarms():
    client, _ = alarm_app()
    with client:
        alarm_id = client.post("/api/alarms", json=FIRE, headers=bearer()).json()["id"]
        ws, socket = listen(client, "user-2")
        try:
            message = socket.receive_json()
            assert message["type"] == "alarm" and message["id"] == alarm_id
        finally:
            ws.__exit__(None, None, None)


def test_own_alarm_is_not_sent_to_the_author():
    client, _ = alarm_app()
    with client:
        ws_mine, mine = listen(client, "user-1")
        ws_theirs, theirs = listen(client, "user-2")
        try:
            first = client.post("/api/alarms", json=FIRE, headers=bearer()).json()["id"]
            assert theirs.receive_json()["id"] == first
            second = client.post("/api/alarms", json=FIRE, headers=bearer("user-2")).json()["id"]
            # The author's socket skips its own alarm: the next thing it sees is the colleague's.
            message = mine.receive_json()
            assert message["id"] == second
            assert not {"owner", "user_id", "email", "ip"} & set(message)
        finally:
            ws_mine.__exit__(None, None, None)
            ws_theirs.__exit__(None, None, None)
        # Replay on (re)connect: the author is not sent their own active alarm, a colleague is.
        ws, socket = listen(client, "user-1")
        try:
            assert socket.receive_json()["id"] == second
            client.post("/api/alarms", json={**FIRE, "kind": "siren"}, headers=bearer("user-2"))
            assert socket.receive_json()["kind"] == "siren"
        finally:
            ws.__exit__(None, None, None)
        ws, socket = listen(client, "user-3")
        try:
            assert {socket.receive_json()["id"] for _ in range(3)} >= {first, second}
        finally:
            ws.__exit__(None, None, None)


class BrokenRecorder:
    async def record(self, entry: dict) -> None:
        raise RuntimeError("database down")


def test_a_failing_recorder_does_not_fail_the_alarm(caplog):
    app = create_app(ai_client=FakeAnthropic(text_response("ok")), verifier=TokenVerifier(secret=SECRET), recorder=BrokenRecorder())
    client = TestClient(app)
    with client, caplog.at_level("ERROR", logger="echo.alarms"):
        raised = client.post("/api/alarms", json=FIRE, headers=bearer())
        assert raised.status_code == 201
        cancelled = client.post(f"/api/alarms/{raised.json()['id']}/cancel", headers=bearer())
        assert cancelled.status_code == 200
    logged = [r for r in caplog.records if r.name == "echo.alarms"]
    assert len(logged) == 2
    assert "ana@firma.ro" in logged[0].getMessage() and logged[0].exc_info


def test_listening_needs_an_account():
    client, _ = alarm_app()
    with client, client.websocket_connect("/ws/alarms") as socket:
        socket.send_json({"type": "auth", "token": "garbage"})
        with pytest.raises(WebSocketDisconnect) as closed:
            socket.receive_json()
        assert closed.value.code == 4401


def test_binary_auth_frame_is_refused():
    client, _ = alarm_app()
    with client, client.websocket_connect("/ws/alarms") as socket:
        socket.send_bytes(b"\x00")
        with pytest.raises(WebSocketDisconnect) as closed:
            socket.receive_json()
        assert closed.value.code == 4401


def test_binary_frame_after_auth_is_ignored():
    client, _ = alarm_app()
    with client:
        ws, socket = listen(client, "user-2")
        try:
            socket.send_bytes(b"\x00")
            assert client.post("/api/alarms", json=FIRE, headers=bearer()).status_code == 201
            assert socket.receive_json()["type"] == "alarm"
        finally:
            ws.__exit__(None, None, None)


def test_listening_needs_accounts_configured():
    client = TestClient(create_app(ai_client=None, verifier=None))
    with client, client.websocket_connect("/ws/alarms") as socket:
        socket.send_json({"type": "auth", "token": "x"})
        with pytest.raises(WebSocketDisconnect) as closed:
            socket.receive_json()
        assert closed.value.code == 4503


def test_fourth_alarm_in_an_hour_is_refused():
    client, _ = alarm_app()
    with client:
        for _ in range(3):
            assert client.post("/api/alarms", json=FIRE, headers=bearer()).status_code == 201
        refused = client.post("/api/alarms", json=FIRE, headers=bearer())
        assert refused.status_code == 429 and "retry-after" in refused.headers
        ok = client.post("/api/ai/simplify", json={"lang": "ro", "text": "salut"}, headers=bearer())
        assert ok.status_code != 429


def test_meeting_sockets_still_work():
    client, _ = alarm_app()
    with client:
        code = client.post("/api/sessions").json()["code"]
        with client.websocket_connect(f"/ws/{code}?role=presenter") as socket:
            assert socket.receive_json()["type"] == "joined"
