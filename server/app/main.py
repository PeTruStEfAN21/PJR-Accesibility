"""FastAPI entry point: meeting sessions, the realtime relay and the AI endpoints."""

import json
import os
from pathlib import Path
from typing import Any

import anthropic
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import ValidationError

from app import agent, ai
from app.protocol import ALLOWED, MAX_MESSAGE_BYTES, ROLES, client_message
from app.schemas import (
    AnswerCheckRequest,
    AnswerCheckResponse,
    AskRequest,
    AskResponse,
    QuestionsRequest,
    QuestionsResponse,
    SimplifyRequest,
    SimplifyResponse,
    SummaryRequest,
    SummaryResponse,
)
from app.sessions import SessionRegistry

_DEFAULT = object()


def _default_ai_client() -> anthropic.AsyncAnthropic | None:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        return None
    return anthropic.AsyncAnthropic()


def create_app(ai_client: Any = _DEFAULT) -> FastAPI:
    app = FastAPI(title="Echo")
    # The presenter page is served from this server, but `flutter run -d chrome` uses its own port.
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    registry = SessionRegistry()
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

    @app.get("/health")
    async def health() -> dict:
        return {"status": "ok"}

    @app.get("/api/config")
    async def config() -> dict:
        return {"public_url": os.environ.get("PUBLIC_URL", "http://localhost:8000")}

    @app.post("/api/sessions", status_code=status.HTTP_201_CREATED)
    async def create_session() -> dict:
        return {"code": registry.create()}

    @app.post("/api/ai/summary")
    async def summary(body: SummaryRequest) -> SummaryResponse:
        return await call_ai(ai.summarize(require_ai(), body.lang, body.lines))

    @app.post("/api/ai/simplify")
    async def simplify(body: SimplifyRequest) -> SimplifyResponse:
        return SimplifyResponse(text=await call_ai(ai.simplify(require_ai(), body.lang, body.text)))

    @app.post("/api/ai/ask")
    async def ask(body: AskRequest) -> AskResponse:
        return await call_ai(agent.ask(require_ai(), body.lang, body.lines, body.question))

    @app.post("/api/ai/answer-check")
    async def answer_check(body: AnswerCheckRequest) -> AnswerCheckResponse:
        return await call_ai(ai.check_answer(require_ai(), body.lang, body.question, body.lines))

    @app.post("/api/ai/questions")
    async def questions(body: QuestionsRequest) -> QuestionsResponse:
        return QuestionsResponse(question_ids=await call_ai(ai.find_questions(require_ai(), body.lang, body.lines)))

    @app.websocket("/ws/{code}")
    async def meeting_socket(websocket: WebSocket, code: str, role: str = "") -> None:
        # Accept before rejecting: a close during the handshake reaches real clients as a bare
        # HTTP 403, while a close after accept carries the code the app uses to stop retrying.
        await websocket.accept()
        session = registry.get(code)
        if session is None:
            await websocket.close(code=4404, reason="unknown session")
            return
        if role not in ROLES:
            await websocket.close(code=4400, reason="role must be presenter or participant")
            return

        session.add(websocket, role)
        await websocket.send_json({"type": "joined", "code": session.code, "role": role, "peers": session.roles()})
        await _broadcast(session, websocket, {"type": "peer", "role": role, "connected": True})

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
                session.touch()
                await _broadcast(session, websocket, message.model_dump())
        except WebSocketDisconnect:
            pass
        finally:
            session.remove(websocket)
            await _broadcast(session, websocket, {"type": "peer", "role": role, "connected": False})

    web_dir = Path(os.environ.get("WEB_DIR", "web"))
    if (web_dir / "index.html").is_file():
        app.mount("/", StaticFiles(directory=web_dir, html=True), name="web")

    return app


async def _broadcast(session, sender, payload: dict) -> None:
    for peer in session.others(sender):
        try:
            await peer.send_json(payload)
        except (RuntimeError, WebSocketDisconnect):
            # Peer dropped mid-send; its own handler cleans it up.
            pass


app = create_app()
