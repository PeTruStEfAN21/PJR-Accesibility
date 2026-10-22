"""The Supabase migrations on a real PostgreSQL: schema, Row Level Security, search, deletion.

Needs TEST_DATABASE_URL pointing at a server where we may create databases, e.g.
postgresql://postgres@localhost:5432/postgres. Skipped otherwise.
"""

import os
import secrets
import uuid
from contextlib import contextmanager
from pathlib import Path

import pytest

psycopg = pytest.importorskip("psycopg")

ADMIN_URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not ADMIN_URL, reason="TEST_DATABASE_URL not set")

ROOT = Path(__file__).resolve().parents[2]
STUB = Path(__file__).parent / "db" / "supabase_stub.sql"
MIGRATIONS = sorted((ROOT / "supabase" / "migrations").glob("*.sql"))


@pytest.fixture(scope="module")
def db():
    name = f"echo_test_{secrets.token_hex(4)}"
    with psycopg.connect(ADMIN_URL, autocommit=True) as admin:
        admin.execute(f'create database "{name}"')
    url = psycopg.conninfo.make_conninfo(ADMIN_URL, dbname=name)
    try:
        with psycopg.connect(url, autocommit=True) as conn:
            conn.execute(STUB.read_text(encoding="utf-8"))
            for migration in MIGRATIONS:
                conn.execute(migration.read_text(encoding="utf-8"))
            yield conn
    finally:
        with psycopg.connect(ADMIN_URL, autocommit=True) as admin:
            admin.execute(f'drop database if exists "{name}" with (force)')


def new_user(db) -> uuid.UUID:
    return db.execute("insert into auth.users default values returning id").fetchone()[0]


@contextmanager
def as_user(db, user_id: uuid.UUID | None):
    """Runs the block the way Supabase runs a request from that user, then rolls back."""
    with db.transaction(force_rollback=True):
        db.execute("set local role " + ("authenticated" if user_id else "anon"))
        db.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(user_id or ""),))
        yield db


def add_meeting(db, owner: uuid.UUID, title: str = "Ședință", lines: tuple[str, ...] = ()) -> uuid.UUID:
    meeting = db.execute(
        "insert into public.meetings (owner_id, title, lang) values (%s, %s, 'ro-RO') returning id",
        (owner, title),
    ).fetchone()[0]
    for seq, text in enumerate(lines, start=1):
        db.execute(
            "insert into public.meeting_lines (meeting_id, seq, caption_id, speaker, text, spoken_at)"
            " values (%s, %s, %s, 'coordinator', %s, now())",
            (meeting, seq, f"c{seq}", text),
        )
    return meeting


def test_new_user_gets_a_profile(db):
    user = new_user(db)
    with as_user(db, user):
        assert db.execute("select id from public.profiles").fetchall() == [(user,)]


def test_users_only_see_their_own_meetings_and_lines(db):
    alice, bob = new_user(db), new_user(db)
    meeting = add_meeting(db, alice, lines=("Raportul se trimite vineri",))

    with as_user(db, bob):
        assert db.execute("select count(*) from public.meetings").fetchone()[0] == 0
        assert db.execute("select count(*) from public.meeting_lines").fetchone()[0] == 0
        assert db.execute("update public.meetings set title = 'x' where id = %s", (meeting,)).rowcount == 0
        assert db.execute("delete from public.meeting_lines where meeting_id = %s", (meeting,)).rowcount == 0

    with as_user(db, alice):
        assert db.execute("select count(*) from public.meeting_lines").fetchone()[0] == 1


def test_nobody_can_add_lines_or_summaries_to_someone_elses_meeting(db):
    alice, bob = new_user(db), new_user(db)
    meeting = add_meeting(db, alice)
    with as_user(db, bob), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute(
            "insert into public.meeting_lines (meeting_id, seq, caption_id, speaker, text, spoken_at)"
            " values (%s, 1, 'c1', 'public', 'intrus', now())",
            (meeting,),
        )
    with as_user(db, bob), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("insert into public.summaries (meeting_id, summary, lang) values (%s, 'x', 'ro')", (meeting,))


def test_meetings_cannot_be_created_for_someone_else(db):
    alice, bob = new_user(db), new_user(db)
    with as_user(db, bob), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("insert into public.meetings (owner_id, lang) values (%s, 'ro-RO')", (alice,))


def test_owner_defaults_to_the_caller(db):
    alice = new_user(db)
    with as_user(db, alice):
        owner = db.execute("insert into public.meetings (lang) values ('ro-RO') returning owner_id").fetchone()[0]
        assert owner == alice


def test_signed_out_requests_see_nothing(db):
    add_meeting(db, new_user(db))
    with as_user(db, None), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select * from public.meetings")


def test_resending_a_caption_does_not_duplicate_it(db):
    alice = new_user(db)
    meeting = add_meeting(db, alice, lines=("Bună ziua",))
    with as_user(db, alice), pytest.raises(psycopg.errors.UniqueViolation):
        db.execute(
            "insert into public.meeting_lines (meeting_id, seq, caption_id, speaker, text, spoken_at)"
            " values (%s, 2, 'c1', 'coordinator', 'Bună ziua', now())",
            (meeting,),
        )


def test_search_finds_only_own_meetings_by_line_or_title(db):
    alice, bob = new_user(db), new_user(db)
    report = add_meeting(db, alice, "Planificare", ("Bună ziua", "Raportul se trimite vineri"))
    add_meeting(db, alice, "Altceva", ("Nimic aici",))
    budget = add_meeting(db, alice, "Buget raport", ())
    add_meeting(db, bob, "Raport Bob", ("Raportul lui Bob",))

    with as_user(db, alice):
        rows = db.execute("select meeting_id, seq, snippet from public.search_meetings('raportul')").fetchall()
        assert rows == [(report, 2, "Raportul se trimite vineri")]
        by_title = db.execute("select meeting_id from public.search_meetings('buget')").fetchall()
        assert by_title == [(budget,)]


def test_delete_my_account_removes_everything(db):
    alice, bob = new_user(db), new_user(db)
    meeting = add_meeting(db, alice, lines=("Ceva",))
    add_meeting(db, bob, lines=("Altceva",))
    db.execute("insert into public.summaries (meeting_id, summary, lang) values (%s, 'Rezumat', 'ro')", (meeting,))

    with db.transaction():
        db.execute("set local role authenticated")
        db.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(alice),))
        db.execute("select public.delete_my_account()")

    assert db.execute("select count(*) from auth.users where id = %s", (alice,)).fetchone()[0] == 0
    assert db.execute("select count(*) from public.meetings where owner_id = %s", (alice,)).fetchone()[0] == 0
    assert db.execute("select count(*) from public.summaries where meeting_id = %s", (meeting,)).fetchone()[0] == 0
    assert db.execute("select count(*) from public.meetings where owner_id = %s", (bob,)).fetchone()[0] == 1


def test_signed_out_cannot_delete_accounts(db):
    with as_user(db, None), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.delete_my_account()")
