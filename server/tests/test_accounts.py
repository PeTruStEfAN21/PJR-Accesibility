import asyncio
import time

import jwt
import pytest
from fastapi.testclient import TestClient

from app.auth import Caller, InvalidToken, TokenVerifier
from app.limits import MemoryLimiter
from app.main import create_app
from tests.fakes import FakeAnthropic, text_response

SECRET = "test-secret-that-is-long-enough-for-hs256"


def token(sub: str = "user-1", *, secret: str = SECRET, aud: str = "authenticated", exp_in: int = 3600) -> str:
    return jwt.encode({"sub": sub, "aud": aud, "exp": int(time.time()) + exp_in}, secret, algorithm="HS256")


def make_client(*responses, **kwargs) -> TestClient:
    return TestClient(create_app(ai_client=FakeAnthropic(*responses), verifier=TokenVerifier(secret=SECRET), **kwargs))


def simplify(client: TestClient, headers: dict | None = None):
    return client.post("/api/ai/simplify", json={"lang": "ro", "text": "Text"}, headers=headers or {})


def test_valid_token_identifies_the_user():
    client = make_client()
    assert client.get("/api/me", headers={"Authorization": f"Bearer {token()}"}).json() == {"user_id": "user-1"}


def test_no_token_is_anonymous():
    assert make_client().get("/api/me").json() == {"user_id": None}


@pytest.mark.parametrize(
    "bad",
    [token(secret="another-secret-also-long-enough-for-hs256"), token(aud="anon"), token(exp_in=-10), "not-a-jwt"],
)
def test_bad_tokens_are_rejected(bad):
    response = make_client().get("/api/me", headers={"Authorization": f"Bearer {bad}"})
    assert response.status_code == 401


def test_tokens_are_ignored_when_accounts_are_not_configured():
    client = TestClient(create_app(ai_client=None, verifier=None))
    assert client.get("/api/me", headers={"Authorization": "Bearer whatever"}).json() == {"user_id": None}


def test_verifier_rejects_missing_subject():
    verifier = TokenVerifier(secret=SECRET)
    unsigned = jwt.encode({"aud": "authenticated", "exp": int(time.time()) + 60}, SECRET, algorithm="HS256")
    with pytest.raises(InvalidToken):
        asyncio.run(verifier.user_id(unsigned))


def test_ai_calls_are_limited_per_hour(monkeypatch):
    monkeypatch.setenv("AI_ANONYMOUS_REQUESTS_PER_HOUR", "2")
    client = make_client(text_response("a"), text_response("b"))
    assert simplify(client).status_code == 200
    assert simplify(client).status_code == 200
    blocked = simplify(client)
    assert blocked.status_code == 429
    assert int(blocked.headers["Retry-After"]) > 0


def test_signed_in_users_have_their_own_budget(monkeypatch):
    monkeypatch.setenv("AI_ANONYMOUS_REQUESTS_PER_HOUR", "1")
    monkeypatch.setenv("AI_REQUESTS_PER_HOUR", "5")
    client = make_client(text_response("a"), text_response("b"))
    assert simplify(client).status_code == 200
    assert simplify(client).status_code == 429
    assert simplify(client, {"Authorization": f"Bearer {token()}"}).status_code == 200


def test_memory_limiter_resets_each_hour():
    now = [7200.0]
    limiter = MemoryLimiter(clock=lambda: now[0])
    assert asyncio.run(limiter.hit("k", 1)) is None
    assert asyncio.run(limiter.hit("k", 1)) == 3601
    now[0] += 3600
    assert asyncio.run(limiter.hit("k", 1)) is None


def test_caller_key_prefers_the_account():
    assert Caller(user_id="u", ip="1.2.3.4").key == "user:u"
    assert Caller(user_id=None, ip="1.2.3.4").key == "ip:1.2.3.4"
