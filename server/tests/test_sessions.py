from app.sessions import ALPHABET, CODE_LENGTH, SWEEP_INTERVAL_SECONDS, SessionRegistry


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def test_create_returns_short_unambiguous_code():
    registry = SessionRegistry()
    code = registry.create()
    assert len(code) == CODE_LENGTH
    assert all(ch in ALPHABET for ch in code)
    for ambiguous in "0O1I":
        assert ambiguous not in ALPHABET


def test_codes_are_unique():
    registry = SessionRegistry()
    codes = {registry.create() for _ in range(200)}
    assert len(codes) == 200


def test_get_is_case_insensitive():
    registry = SessionRegistry()
    code = registry.create()
    assert registry.get(code.lower()) is registry.get(code)


def test_unknown_code_returns_none():
    assert SessionRegistry().get("ZZZZZZ") is None


def test_session_expires_after_ttl_without_activity():
    clock = FakeClock()
    registry = SessionRegistry(ttl_seconds=60, clock=clock)
    code = registry.create()
    clock.now += 61
    assert registry.get(code) is None


def test_touch_keeps_session_alive():
    clock = FakeClock()
    registry = SessionRegistry(ttl_seconds=60, clock=clock)
    code = registry.create()
    clock.now += 50
    registry.get(code).touch()
    clock.now += 50
    assert registry.get(code) is not None


def test_session_with_connected_peer_does_not_expire():
    clock = FakeClock()
    registry = SessionRegistry(ttl_seconds=60, clock=clock)
    code = registry.create()
    registry.get(code).add(object(), "presenter")
    clock.now += 3600
    assert registry.get(code) is not None


def test_expired_session_is_gone_even_between_sweeps():
    clock = FakeClock()
    registry = SessionRegistry(ttl_seconds=60, clock=clock)
    old = registry.create()
    clock.now += 30
    fresh = registry.create()
    clock.now += 31
    assert registry.get(old) is None
    assert registry.get(fresh) is not None


def test_sweep_runs_at_most_once_per_interval():
    # A full scan on every create/join stalls the event loop once the registry is large.
    clock = FakeClock()
    registry = SessionRegistry(ttl_seconds=10, clock=clock)
    codes = [registry.create() for _ in range(5)]
    clock.now += 11
    registry.create()
    assert len(registry._sessions) == 6
    assert registry.get(codes[0]) is None
    clock.now += SWEEP_INTERVAL_SECONDS
    registry.create()
    assert all(code not in registry._sessions for code in codes)
