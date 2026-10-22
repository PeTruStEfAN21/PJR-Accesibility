"""Where live meeting sessions live.

LocalHub keeps them in this process: enough for one server. RedisHub keeps them in
Redis and relays messages through pub/sub, so the presenter and the participants
can be connected to different server instances behind a load balancer.
Both deliver a message to every socket of the session except the sender's.
"""

import asyncio
import json
import logging
import secrets
from collections.abc import Awaitable, Callable
from typing import Any, Protocol

from starlette.websockets import WebSocketDisconnect

from app.sessions import ALPHABET, CODE_LENGTH, DEFAULT_TTL_SECONDS, SessionRegistry

log = logging.getLogger(__name__)

Send = Callable[[Any, dict], Awaitable[None]]


async def send_json(socket: Any, payload: dict) -> None:
    try:
        await socket.send_json(payload)
    except (RuntimeError, WebSocketDisconnect):
        # Peer dropped mid-send; its own handler cleans it up.
        pass


class Hub(Protocol):
    async def start(self) -> None: ...
    async def close(self) -> None: ...
    async def create(self) -> str: ...

    async def join(self, code: str, socket: Any, role: str) -> tuple[str, dict[str, int]] | None:
        """Adds the socket; returns the canonical code and the roles now connected, or None if unknown."""

    async def leave(self, code: str, socket: Any, role: str) -> None: ...
    async def touch(self, code: str) -> None: ...
    async def publish(self, code: str, sender: Any, payload: dict) -> None: ...


class LocalHub:
    def __init__(self, registry: SessionRegistry | None = None, send: Send = send_json) -> None:
        self._registry = registry or SessionRegistry()
        self._send = send

    async def start(self) -> None:
        pass

    async def close(self) -> None:
        pass

    async def create(self) -> str:
        return self._registry.create()

    async def join(self, code: str, socket: Any, role: str) -> tuple[str, dict[str, int]] | None:
        session = self._registry.get(code)
        if session is None:
            return None
        session.add(socket, role)
        return session.code, session.roles()

    async def leave(self, code: str, socket: Any, role: str) -> None:
        if session := self._registry.get(code):
            session.remove(socket)

    async def touch(self, code: str) -> None:
        if session := self._registry.get(code):
            session.touch()

    async def publish(self, code: str, sender: Any, payload: dict) -> None:
        if session := self._registry.get(code):
            for peer in session.others(sender):
                await self._send(peer, payload)


class RedisHub:
    """Sessions in Redis. Keys expire after the TTL without activity, like LocalHub.

    echo:session:{code}        exists while the session is valid
    echo:session:{code}:peers  hash role -> connected sockets, across all instances
    echo:relay:{code}          pub/sub channel with {"from": socket id, "payload": ...}
    """

    PREFIX = "echo:session:"
    RELAY = "echo:relay:"

    def __init__(self, redis: Any, ttl_seconds: int = DEFAULT_TTL_SECONDS, send: Send = send_json) -> None:
        self._redis = redis
        self._ttl = ttl_seconds
        self._send = send
        self._instance = secrets.token_hex(4)
        self._next_id = 0
        # Sockets connected to this instance: code -> {socket: socket id}.
        self._local: dict[str, dict[Any, str]] = {}
        self._listener: asyncio.Task | None = None
        self._pubsub: Any = None

    async def start(self) -> None:
        self._pubsub = self._redis.pubsub()
        await self._pubsub.psubscribe(f"{self.RELAY}*")
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

    async def create(self) -> str:
        while True:
            code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))
            if await self._redis.set(self._key(code), "1", nx=True, ex=self._ttl):
                return code

    async def join(self, code: str, socket: Any, role: str) -> tuple[str, dict[str, int]] | None:
        code = code.upper()
        if not await self._redis.exists(self._key(code)):
            return None
        self._next_id += 1
        self._local.setdefault(code, {})[socket] = f"{self._instance}:{self._next_id}"
        await self._redis.hincrby(self._peers(code), role, 1)
        await self.touch(code)
        counts = await self._redis.hgetall(self._peers(code))
        return code, {role: int(n) for role, n in counts.items() if int(n) > 0}

    async def leave(self, code: str, socket: Any, role: str) -> None:
        code = code.upper()
        sockets = self._local.get(code, {})
        sockets.pop(socket, None)
        if not sockets:
            self._local.pop(code, None)
        await self._redis.hincrby(self._peers(code), role, -1)
        await self.touch(code)

    async def touch(self, code: str) -> None:
        code = code.upper()
        async with self._redis.pipeline(transaction=False) as pipe:
            pipe.expire(self._key(code), self._ttl)
            pipe.expire(self._peers(code), self._ttl)
            await pipe.execute()

    async def publish(self, code: str, sender: Any, payload: dict) -> None:
        code = code.upper()
        sender_id = self._local.get(code, {}).get(sender, "")
        await self._redis.publish(f"{self.RELAY}{code}", json.dumps({"from": sender_id, "payload": payload}))

    async def _listen(self) -> None:
        while True:
            try:
                message = await self._pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if message is None:
                    continue
                code = message["channel"].removeprefix(self.RELAY)
                envelope = json.loads(message["data"])
                for socket, socket_id in list(self._local.get(code, {}).items()):
                    if socket_id != envelope["from"]:
                        await self._send(socket, envelope["payload"])
            except asyncio.CancelledError:
                raise
            except Exception:
                # A bad message or a Redis hiccup must not stop the relay for everyone.
                log.exception("relay listener error")
                await asyncio.sleep(0.5)

    def _key(self, code: str) -> str:
        return f"{self.PREFIX}{code}"

    def _peers(self, code: str) -> str:
        return f"{self.PREFIX}{code}:peers"
