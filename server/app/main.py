"""FastAPI entry point: meeting sessions, the realtime relay and the AI endpoints."""

import json
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import anthropic
from fastapi import Depends, FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import ValidationError

from app import agent, ai
from app.auth import Caller, InvalidToken, TokenVerifier, verifier_from_env
from app.hub import Hub, LocalHub, RedisHub
from app.limits import Limiter, MemoryLimiter, RedisLimiter
from app.protocol import ALLOWED, MAX_MESSAGE_BYTES, ROLES, client_message
from app.schemas import (
    AskRequest,
    AskResponse,
    SimplifyRequest,
    SimplifyResponse,
    SummaryRequest,
    SummaryResponse,
)

_DEFAULT = object()


def _default_ai_client() -> anthropic.AsyncAnthropic | None:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        return None
    return anthropic.AsyncAnthropic()


def _limit(name: str, default: int) -> int:
    return int(os.environ.get(name) or default)


def create_app(
    ai_client: Any = _DEFAULT,
    *,
    hub: Hub | None = None,
    limiter: Limiter | None = None,
    verifier: Any = _DEFAULT,
) -> FastAPI:
    # REDIS_URL set: sessions and limits are shared by every server instance. Unset: one process.
    redis_url = os.environ.get("REDIS_URL")
    redis = None
    if redis_url and (hub is None or limiter is None):
        import redis.asyncio as aioredis

        redis = aioredis.from_url(redis_url, decode_responses=True)
    hub = hub or (RedisHub(redis) if redis else LocalHub())
    limiter = limiter or (RedisLimiter(redis) if redis else MemoryLimiter())
    verifier: TokenVerifier | None = verifier_from_env() if verifier is _DEFAULT else verifier
    user_limit = _limit("AI_REQUESTS_PER_HOUR", 120)
    anonymous_limit = _limit("AI_ANONYMOUS_REQUESTS_PER_HOUR", 60)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        await hub.start()
        try:
            yield
        finally:
            await hub.close()
            if redis is not None:
                await redis.aclose()

    app = FastAPI(title="Echo", lifespan=lifespan)
    # The presenter page is served from this server, but `flutter run -d chrome` uses its own port.
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    client = _default_ai_client() if ai_client is _DEFAULT else ai_client

    def require_ai() -> Any:
        if client is None:
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "AI not configured: set ANTHROPIC_API_KEY in .env")
        return client

    async def call_ai(coro):
        try:
            return await coro
        except ai.AIRefused as exc:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(exc)) from exc
        except anthropic.AuthenticationError as exc:
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Invalid ANTHROPIC_API_KEY") from exc
        except (anthropic.APIConnectionError, anthropic.APIStatusError) as exc:
            raise HTTPException(status.HTTP_502_BAD_GATEWAY, "AI service unavailable, try again") from exc

    async def caller(request: Request) -> Caller:
        ip = request.client.host if request.client else "unknown"
        header = request.headers.get("authorization", "")
        if not header.lower().startswith("bearer ") or verifier is None:
            # Accounts are optional: without a token (or without Supabase configured) the caller is anonymous.
            return Caller(user_id=None, ip=ip)
        try:
            return Caller(user_id=await verifier.user_id(header[7:].strip()), ip=ip)
        except InvalidToken as exc:
            raise HTTPException(
                status.HTTP_401_UNAUTHORIZED,
                "Invalid or expired session, sign in again",
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc

    async def ai_caller(who: Caller = Depends(caller)) -> Caller:
        retry_after = await limiter.hit(who.key, user_limit if who.user_id else anonymous_limit)
        if retry_after is not None:
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                "Too many AI requests, try again later",
                headers={"Retry-After": str(retry_after)},
            )
        return who

    @app.get("/health")
    async def health() -> dict:
        return {"status": "ok"}

    @app.get("/api/config")
    async def config() -> dict:
        return {"public_url": os.environ.get("PUBLIC_URL", "http://localhost:8000")}

    @app.get("/api/me")
    async def me(who: Caller = Depends(caller)) -> dict:
        return {"user_id": who.user_id}

    @app.post("/api/sessions", status_code=status.HTTP_201_CREATED)
    async def create_session() -> dict:
        return {"code": await hub.create()}

    @app.post("/api/ai/summary")
    async def summary(body: SummaryRequest, _: Caller = Depends(ai_caller)) -> SummaryResponse:
        return await call_ai(ai.summarize(require_ai(), body.lang, body.lines))

    @app.post("/api/ai/simplify")
    async def simplify(body: SimplifyRequest, _: Caller = Depends(ai_caller)) -> SimplifyResponse:
        return SimplifyResponse(text=await call_ai(ai.simplify(require_ai(), body.lang, body.text)))

    @app.post("/api/ai/ask")
    async def ask(body: AskRequest, _: Caller = Depends(ai_caller)) -> AskResponse:
        return await call_ai(agent.ask(require_ai(), body.lang, body.lines, body.question))

    @app.websocket("/ws/{code}")
    async def meeting_socket(websocket: WebSocket, code: str, role: str = "") -> None:
        # Accept before rejecting: a close during the handshake reaches real clients as a bare
        # HTTP 403, while a close after accept carries the code the app uses to stop retrying.
        await websocket.accept()
        if role not in ROLES:
            await websocket.close(code=4400, reason="role must be presenter or participant")
            return
        joined = await hub.join(code, websocket, role)
        if joined is None:
            await websocket.close(code=4404, reason="unknown session")
            return

        code, peers = joined
        await websocket.send_json({"type": "joined", "code": code, "role": role, "peers": peers})
        await hub.publish(code, websocket, {"type": "peer", "role": role, "connected": True})

        try:
            while True:
                raw = await websocket.receive_text()
                error = None
                if len(raw.encode()) > MAX_MESSAGE_BYTES:
                    error = "message too large"
                else:
                    try:
                        message = client_message.validate_python(json.loads(raw))
                    except (json.JSONDecodeError, ValidationError):
                        error = "invalid message"
                    else:
                        if message.type not in ALLOWED[role]:
                            error = f"{role} cannot send {message.type}"
                if error:
                    await websocket.send_json({"type": "error", "message": error})
                    continue
                await hub.touch(code)
                await hub.publish(code, websocket, message.model_dump())
        except WebSocketDisconnect:
            pass
        finally:
            await hub.publish(code, websocket, {"type": "peer", "role": role, "connected": False})
            await hub.leave(code, websocket, role)

    web_dir = Path(os.environ.get("WEB_DIR", "web"))
    if (web_dir / "index.html").is_file():
        app.mount("/", StaticFiles(directory=web_dir, html=True), name="web")

    return app


app = create_app()
