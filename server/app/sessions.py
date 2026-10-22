"""In-memory meeting sessions that pair a presenter device with participants."""

import secrets
import time
from collections.abc import Callable
from typing import Any

# No 0/O/1/I so the code can be read aloud or typed without mistakes.
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6
DEFAULT_TTL_SECONDS = 12 * 60 * 60


class Session:
    def __init__(self, code: str, clock: Callable[[], float]) -> None:
        self.code = code
        self._clock = clock
        self.last_active = clock()
        self.peers: dict[Any, str] = {}

    def touch(self) -> None:
        self.last_active = self._clock()

    def add(self, socket: Any, role: str) -> None:
        self.peers[socket] = role
        self.touch()

    def remove(self, socket: Any) -> str | None:
        self.touch()
        return self.peers.pop(socket, None)

    def roles(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for role in self.peers.values():
            counts[role] = counts.get(role, 0) + 1
        return counts

    def others(self, socket: Any) -> list[Any]:
        return [peer for peer in self.peers if peer is not socket]


class SessionRegistry:
    def __init__(
        self,
        ttl_seconds: float = DEFAULT_TTL_SECONDS,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._ttl = ttl_seconds
        self._clock = clock
        self._sessions: dict[str, Session] = {}

    def create(self) -> str:
        self._prune()
        while True:
            code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))
            if code not in self._sessions:
                self._sessions[code] = Session(code, self._clock)
                return code

    def get(self, code: str) -> Session | None:
        self._prune()
        return self._sessions.get(code.upper())

    def _prune(self) -> None:
        now = self._clock()
        expired = [
            code
            for code, session in self._sessions.items()
            if not session.peers and now - session.last_active > self._ttl
        ]
        for code in expired:
            del self._sessions[code]
