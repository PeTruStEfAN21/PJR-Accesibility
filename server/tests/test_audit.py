"""DatabaseRecorder: colleague alarms written to the activity log through the echo_audit role."""

import asyncio
import os
import time
import uuid
from datetime import datetime, timezone

import psycopg
import pytest
from fastapi.testclient import TestClient

from app.alarms import DatabaseRecorder, LogRecorder, purge_daily, recorder_from_env
from app.main import create_app
from tests.fakes import FakeAnthropic

# A moment already past: the database never dates a row in the future.
PAST = round(time.time()) - 60.5
USER = "8f14e45f-ceea-467f-a0e6-7a1b2c3d4e5f"
ENTRY = {
    "event": "raised",
    "id": "a1",
    "kind": "fire",
    "at": 1792742400.5,
    "lat": 44.43,
    "lon": 26.10,
    "accuracy_m": 12.0,
    "user_id": USER,
    "email": "ana@firma.ro",
    "ip": "203.0.113.7",
}


class FakeCursor:
    def __init__(self, row) -> None:
        self._row = row

    async def fetchone(self):
        return self._row


class FakeConnection:
    def __init__(self, fail: Exception | None = None) -> None:
        self.calls: list[tuple[str, tuple]] = []
        self.fail = fail
        self.closed = False

    async def execute(self, sql: str, params: tuple = ()):
        self.calls.append((sql, params))
        if self.fail:
            raise self.fail
        return FakeCursor((7,))

    async def close(self) -> None:
        self.closed = True


def connector(*connections: FakeConnection):
    """A connect() that hands out the given connections in order."""
    pending = list(connections)
    urls: list[str] = []

    async def connect(url: str):
        urls.append(url)
        return pending.pop(0)

    return connect, urls


def test_an_entry_becomes_a_call_to_record_colleague_alarm():
    conn = FakeConnection()
    connect, urls = connector(conn)
    recorder = DatabaseRecorder("postgresql://audit", connect=connect)
    asyncio.run(recorder.record(ENTRY))

    assert urls == ["postgresql://audit"]
    sql, params = conn.calls[0]
    assert "public.record_colleague_alarm" in sql
    assert params == (
        "raised", "a1", "fire", datetime.fromtimestamp(1792742400.5, timezone.utc),
        44.43, 26.10, 12.0, uuid.UUID(USER), "ana@firma.ro", "203.0.113.7",
    )
    assert params[3].tzinfo is not None


@pytest.mark.parametrize("ip", ["unknown", "", None, "testclient", "999.1.1.1"])
def test_an_address_that_is_not_an_ip_is_stored_as_null(ip):
    conn = FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])
    asyncio.run(recorder.record({**ENTRY, "ip": ip}))
    assert conn.calls[0][1][-1] is None


def test_an_ipv6_address_is_kept():
    conn = FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])
    asyncio.run(recorder.record({**ENTRY, "ip": "2001:db8::1"}))
    assert conn.calls[0][1][-1] == "2001:db8::1"


def test_a_cancel_for_an_alarm_the_server_forgot_is_still_recorded():
    conn = FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])
    forgotten = {**ENTRY, "event": "cancelled", "kind": None, "lat": None, "lon": None, "accuracy_m": None}
    asyncio.run(recorder.record(forgotten))
    assert conn.calls[0][1][:7] == (
        "cancelled", "a1", None, datetime.fromtimestamp(1792742400.5, timezone.utc), None, None, None,
    )


def test_the_connection_is_reused():
    conn = FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])

    async def scenario():
        await recorder.record(ENTRY)
        await recorder.record(ENTRY)

    asyncio.run(scenario())
    assert len(conn.calls) == 2


def test_a_broken_connection_is_replaced():
    broken, fresh = FakeConnection(psycopg.OperationalError("server closed the connection")), FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(broken, fresh)[0])
    asyncio.run(recorder.record(ENTRY))
    assert broken.closed and len(fresh.calls) == 1


def test_a_database_that_stays_down_raises_so_the_entry_is_logged():
    down = psycopg.OperationalError("connection refused")
    recorder = DatabaseRecorder("x", connect=connector(FakeConnection(down), FakeConnection(down))[0])
    with pytest.raises(psycopg.OperationalError):
        asyncio.run(recorder.record(ENTRY))


def test_an_unreachable_database_raises():
    async def connect(url: str):
        raise psycopg.OperationalError("no route to host")

    with pytest.raises(psycopg.OperationalError):
        asyncio.run(DatabaseRecorder("x", connect=connect).record(ENTRY))


def test_a_rejected_row_is_not_retried():
    conn = FakeConnection(psycopg.errors.CheckViolation("bad kind"))
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])
    with pytest.raises(psycopg.errors.CheckViolation):
        asyncio.run(recorder.record(ENTRY))
    assert len(conn.calls) == 1


def test_purge_and_close():
    conn = FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])

    async def scenario():
        assert await recorder.purge() == 7
        await recorder.close()

    asyncio.run(scenario())
    assert "public.purge_activity_log()" in conn.calls[0][0]
    assert conn.closed


def test_purge_runs_after_startup_then_every_interval_and_survives_failures(caplog):
    calls = 0

    class Flaky:
        async def purge(self) -> int:
            nonlocal calls
            calls += 1
            if calls == 1:
                raise psycopg.OperationalError("down")
            return 0

    async def scenario():
        task = asyncio.create_task(purge_daily(Flaky(), first=0, every=0.01))
        while calls < 3:
            await asyncio.sleep(0.005)
        task.cancel()

    with caplog.at_level("ERROR", logger="app.alarms"):
        asyncio.run(scenario())
    assert calls >= 3
    assert any("purge" in r.getMessage() for r in caplog.records)


def test_without_the_variable_alarms_go_to_the_log(monkeypatch):
    monkeypatch.delenv("AUDIT_DATABASE_URL", raising=False)
    assert isinstance(recorder_from_env(), LogRecorder)


def test_with_the_variable_alarms_go_to_the_database(monkeypatch):
    monkeypatch.setenv("AUDIT_DATABASE_URL", "postgresql://echo_audit@db/postgres")
    assert isinstance(recorder_from_env(), DatabaseRecorder)


def test_the_app_starts_and_stops_with_the_database_recorder():
    conn = FakeConnection()
    recorder = DatabaseRecorder("x", connect=connector(conn)[0])
    with TestClient(create_app(ai_client=FakeAnthropic(), verifier=None, recorder=recorder)) as client:
        assert client.get("/health").status_code == 200
    assert not conn.calls  # The first purge waits a minute; shutdown cancels it.


# --- against a real Postgres -------------------------------------------------------------

if os.environ.get("TEST_DATABASE_URL"):
    from tests.test_database import company, db, email_of  # noqa: F401  (db is a fixture)


@pytest.mark.skipif(not os.environ.get("TEST_DATABASE_URL"), reason="TEST_DATABASE_URL not set")
def test_a_raised_alarm_lands_in_the_activity_log_with_its_company(db):  # noqa: F811
    org, _, worker = company(db)
    # Connects as the superuser but acts as echo_audit for the whole session: the cluster's role stays nologin.
    url = psycopg.conninfo.make_conninfo(db.info.dsn, options="-c role=echo_audit")
    recorder = DatabaseRecorder(url)

    async def scenario():
        try:
            await recorder.record({**ENTRY, "at": PAST, "user_id": str(worker), "email": email_of(db, worker)})
            return await recorder.purge()
        finally:
            await recorder.close()

    # psycopg's async connections need a selector loop (Windows defaults to the proactor).
    assert asyncio.run(scenario(), loop_factory=asyncio.SelectorEventLoop) == 0
    row = db.execute(
        "select a.event::text, a.ref, a.alarm_kind, host(a.ip), a.at, o.org_id"
        " from public.activity_log a join public.activity_log_orgs o on o.entry_id = a.id"
        " where a.actor_id = %s",
        (worker,),
    ).fetchall()
    assert row == [(
        "colleague_alarm_raised", "a1", "fire", "203.0.113.7",
        datetime.fromtimestamp(PAST, timezone.utc), org,
    )]


class HangingConnection(FakeConnection):
    """Accepts the connection, then never answers."""

    async def execute(self, sql: str, params: tuple = ()):
        self.calls.append((sql, params))
        await asyncio.Event().wait()


def test_a_database_that_stops_answering_does_not_hold_the_alarm_and_is_replaced():
    hanging, fresh = HangingConnection(), FakeConnection()
    connect, _ = connector(hanging, fresh)
    recorder = DatabaseRecorder("postgresql://audit", connect=connect, timeout=0.1)

    async def scenario():
        with pytest.raises(TimeoutError):
            await recorder.record(ENTRY)
        await recorder.record(ENTRY)

    asyncio.run(scenario())
    assert len(fresh.calls) == 1
