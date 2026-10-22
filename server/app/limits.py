"""Hourly limits on AI calls, so nobody can run up the Claude bill.

Fixed one-hour windows per caller key. In memory for a single server; in Redis
when several instances must share the count.
"""

import time
from collections.abc import Callable
from typing import Any, Protocol

WINDOW_SECONDS = 3600


class Limiter(Protocol):
    async def hit(self, key: str, limit: int) -> int | None:
        """Counts one call. Returns None if allowed, else the seconds until the window resets."""


class MemoryLimiter:
    def __init__(self, clock: Callable[[], float] = time.time) -> None:
        self._clock = clock
        self._counts: dict[str, tuple[int, int]] = {}

    async def hit(self, key: str, limit: int) -> int | None:
        now = self._clock()
        window = int(now // WINDOW_SECONDS)
        if len(self._counts) > 10_000:
            # Forget finished windows so the dict cannot grow forever.
            self._counts = {k: v for k, v in self._counts.items() if v[0] == window}
        start, count = self._counts.get(key, (window, 0))
        if start != window:
            count = 0
        count += 1
        self._counts[key] = (window, count)
        if count > limit:
            return int((window + 1) * WINDOW_SECONDS - now) + 1
        return None


class RedisLimiter:
    def __init__(self, redis: Any) -> None:
        self._redis = redis

    async def hit(self, key: str, limit: int) -> int | None:
        name = f"echo:limit:{key}"
        async with self._redis.pipeline(transaction=True) as pipe:
            pipe.incr(name)
            pipe.expire(name, WINDOW_SECONDS, nx=True)
            pipe.ttl(name)
            count, _, ttl = await pipe.execute()
        if count > limit:
            return max(int(ttl), 1)
        return None
