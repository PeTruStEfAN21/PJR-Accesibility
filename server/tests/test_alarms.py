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
