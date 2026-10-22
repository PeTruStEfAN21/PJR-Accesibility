from app.sessions import ALPHABET, CODE_LENGTH, SessionRegistry


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
