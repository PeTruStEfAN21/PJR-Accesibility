"""Emergency alarms raised by a colleague, and the feed that delivers them.

An alarm is a point in space and time: kind, position, accuracy. Sockets only ever
see Alarm.public(); who raised it (owner, email, ip) stays on the server and goes
to the AlarmRecorder. A socket subscribes with the listener's user id, so nobody is sent
their own alarm (live or in the active list). LocalAlarmFeed keeps alarms in this process; RedisAlarmFeed
keeps them in Redis and relays through pub/sub, like RedisHub, so every instance
reaches its own sockets. An alarm counts as active for 15 minutes unless cancelled.
"""

import asyncio
import json
import logging
import secrets
import time
from collections.abc import Callable
from dataclasses import asdict, dataclass, field
from typing import Any, Literal, Protocol

from pydantic import BaseModel, Field

from app.hub import Send, send_json

log = logging.getLogger(__name__)

AlarmKind = Literal["fire", "evacuation", "siren", "machine"]
CancelResult = Literal["ok", "missing", "forbidden"]

ACTIVE_SECONDS = 900


class AlarmIn(BaseModel):
    kind: AlarmKind
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    accuracy_m: float = Field(ge=0)


@dataclass
class Alarm:
    kind: AlarmKind
    at: float
    lat: float
    lon: float
    accuracy_m: float
    id: str = field(default_factory=lambda: secrets.token_urlsafe(8))
    cancelled: bool = False

    def public(self) -> dict:
        return {
            "type": "alarm",
            "id": self.id,
            "kind": self.kind,
            "at": self.at,
            "lat": self.lat,
            "lon": self.lon,
            "accuracy_m": self.accuracy_m,
        }


def cancelled_message(alarm_id: str) -> dict:
    return {"type": "alarm_cancelled", "id": alarm_id}


class AlarmRecorder(Protocol):
    async def record(self, entry: dict) -> None:
        """entry: event (raised | cancelled), id, kind, at, lat, lon, accuracy_m, user_id, email, ip."""


class LogRecorder:
    """Default recorder: one JSON line per event, visible in `docker compose logs`."""

    def __init__(self) -> None:
        self._log = logging.getLogger("echo.alarms")

    async def record(self, entry: dict) -> None:
        self._log.warning(json.dumps(entry, ensure_ascii=False))


class AlarmFeed(Protocol):
    async def start(self) -> None: ...
    async def close(self) -> None: ...
    async def add(self, alarm: Alarm, owner: str) -> None: ...
    async def cancel(self, alarm_id: str, owner: str) -> CancelResult: ...
    async def active(self, now: float, viewer: str | None = None) -> list[Alarm]: ...
    def subscribe(self, socket: Any, user_id: str | None = None) -> None: ...
    def unsubscribe(self, socket: Any) -> None: ...


async def _deliver(send: Send, sockets: dict[Any, str | None], payload: dict, owner: str | None) -> None:
    """Sends payload to every socket except those of the alarm's owner."""
    for socket, user_id in list(sockets.items()):
        if owner is None or user_id != owner:
            await send(socket, payload)


class LocalAlarmFeed:
    def __init__(self, send: Send = send_json, clock: Callable[[], float] = time.time) -> None:
        self._send = send
        self._clock = clock
        self._alarms: dict[str, tuple[Alarm, str]] = {}
        self._sockets: dict[Any, str | None] = {}

    async def start(self) -> None:
        pass

    async def close(self) -> None:
        pass

    async def add(self, alarm: Alarm, owner: str) -> None:
        self._alarms[alarm.id] = (alarm, owner)
        await self._broadcast(alarm.public(), owner)

    async def cancel(self, alarm_id: str, owner: str) -> CancelResult:
        entry = self._alarms.get(alarm_id)
        if entry is None:
            return "missing"
        if entry[1] != owner:
            return "forbidden"
        entry[0].cancelled = True
        del self._alarms[alarm_id]
        await self._broadcast(cancelled_message(alarm_id))
        return "ok"

    async def active(self, now: float, viewer: str | None = None) -> list[Alarm]:
        return [
            a
            for a, owner in self._alarms.values()
            if not a.cancelled and now - a.at <= ACTIVE_SECONDS and (viewer is None or owner != viewer)
        ]

    def subscribe(self, socket: Any, user_id: str | None = None) -> None:
        self._sockets[socket] = user_id

    def unsubscribe(self, socket: Any) -> None:
        self._sockets.pop(socket, None)

    async def _broadcast(self, payload: dict, owner: str | None = None) -> None:
        await _deliver(self._send, self._sockets, payload, owner)


class RedisAlarmFeed:
    """Alarms in Redis.

    echo:alarms:active  hash alarm id -> JSON of the alarm plus its owner; expires 15 min after the last write
    echo:alarms         pub/sub channel carrying {"owner", "payload"}; only the payload reaches sockets
    """

    ACTIVE = "echo:alarms:active"
    CHANNEL = "echo:alarms"

    def __init__(self, redis: Any, send: Send = send_json, clock: Callable[[], float] = time.time) -> None:
        self._redis = redis
        self._send = send
        self._clock = clock
        self._sockets: dict[Any, str | None] = {}
        self._listener: asyncio.Task | None = None
        self._pubsub: Any = None

    async def start(self) -> None:
        self._pubsub = self._redis.pubsub()
        await self._pubsub.subscribe(self.CHANNEL)
        self._listener = asyncio.create_task(self._listen())

    async def close(self) -> None:
        if self._listener:
            self._listener.cancel()
            try:
                await self._listener
            except asyncio.CancelledError:
                pass
        if self._pubsub:
            await self._pubsub.aclose()

    async def add(self, alarm: Alarm, owner: str) -> None:
        await self._redis.hset(self.ACTIVE, alarm.id, json.dumps({**asdict(alarm), "owner": owner}))
        await self._redis.expire(self.ACTIVE, ACTIVE_SECONDS)
        await self._redis.publish(self.CHANNEL, json.dumps({"owner": owner, "payload": alarm.public()}))

    async def cancel(self, alarm_id: str, owner: str) -> CancelResult:
        raw = await self._redis.hget(self.ACTIVE, alarm_id)
        if raw is None:
            return "missing"
        if json.loads(raw)["owner"] != owner:
            return "forbidden"
        await self._redis.hdel(self.ACTIVE, alarm_id)
        await self._redis.publish(self.CHANNEL, json.dumps({"owner": None, "payload": cancelled_message(alarm_id)}))
        return "ok"

    async def active(self, now: float, viewer: str | None = None) -> list[Alarm]:
        alarms: list[Alarm] = []
        stale: list[str] = []
        for alarm_id, raw in (await self._redis.hgetall(self.ACTIVE)).items():
            data = json.loads(raw)
            owner = data.pop("owner")
            alarm = Alarm(**data)
            if alarm.cancelled or now - alarm.at > ACTIVE_SECONDS:
                stale.append(alarm_id)
            elif viewer is None or owner != viewer:
                alarms.append(alarm)
        if stale:
            await self._redis.hdel(self.ACTIVE, *stale)
        return alarms

    def subscribe(self, socket: Any, user_id: str | None = None) -> None:
        self._sockets[socket] = user_id

    def unsubscribe(self, socket: Any) -> None:
        self._sockets.pop(socket, None)

    async def _listen(self) -> None:
        while True:
            try:
                message = await self._pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if message is None:
                    continue
                envelope = json.loads(message["data"])
                await _deliver(self._send, self._sockets, envelope["payload"], envelope.get("owner"))
            except asyncio.CancelledError:
                raise
            except Exception:
                # A bad message or a Redis hiccup must not stop alarms for everyone.
                log.exception("alarm listener error")
                await asyncio.sleep(0.5)
