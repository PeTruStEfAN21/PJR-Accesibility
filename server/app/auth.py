"""Who is calling: Supabase access tokens, verified locally.

The phone signs in with Supabase and sends its access token as `Authorization: Bearer`.
Projects with the new signing keys are verified against the project's public JWKS;
SUPABASE_JWT_SECRET (legacy shared secret, also what `supabase start` uses) takes
precedence when set. Signing in is optional: without a token the caller is anonymous.
"""

import asyncio
import os
from dataclasses import dataclass

import jwt

AUDIENCE = "authenticated"


class InvalidToken(Exception):
    pass


@dataclass(frozen=True)
class Caller:
    user_id: str | None
    ip: str

    @property
    def key(self) -> str:
        """What rate limits count against: the account when signed in, else the address."""
        return f"user:{self.user_id}" if self.user_id else f"ip:{self.ip}"


class TokenVerifier:
    def __init__(self, *, secret: str | None = None, jwks_url: str | None = None) -> None:
        if not secret and not jwks_url:
            raise ValueError("TokenVerifier needs a secret or a JWKS URL")
        self._secret = secret
        self._jwks = jwt.PyJWKClient(jwks_url, cache_keys=True) if jwks_url and not secret else None

    async def user_id(self, token: str) -> str:
        try:
            if self._jwks is not None:
                # Fetching the keys is blocking I/O (cached after the first call).
                key = (await asyncio.to_thread(self._jwks.get_signing_key_from_jwt, token)).key
                algorithms = ["ES256", "RS256", "EdDSA"]
            else:
                key = self._secret
                algorithms = ["HS256"]
            claims = jwt.decode(token, key, algorithms=algorithms, audience=AUDIENCE, options={"require": ["sub", "exp"]})
        except (jwt.PyJWTError, jwt.PyJWKClientError) as exc:
            raise InvalidToken(str(exc)) from exc
        return claims["sub"]


def verifier_from_env() -> TokenVerifier | None:
    secret = os.environ.get("SUPABASE_JWT_SECRET") or None
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    if not secret and not url:
        return None
    return TokenVerifier(secret=secret, jwks_url=f"{url}/auth/v1/.well-known/jwks.json" if url else None)
