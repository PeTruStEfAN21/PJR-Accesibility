import asyncio
import time

import jwt
from fastapi.testclient import TestClient

from app.auth import Identity, TokenVerifier
from app.main import create_app
from tests.fakes import FakeAnthropic
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


def test_public_message_has_no_identity():
    keys = set(make_alarm().public())
    assert keys == {"type", "id", "kind", "at", "lat", "lon", "accuracy_m"}
    assert not keys & {"user_id", "email", "ip", "owner"}
