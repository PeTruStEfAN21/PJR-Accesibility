"""The Supabase migrations on a real PostgreSQL: schema, Row Level Security, search, deletion.

Needs TEST_DATABASE_URL pointing at a server where we may create databases, e.g.
postgresql://postgres@localhost:5432/postgres. Skipped otherwise.
"""

import json
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
    email = f"u{secrets.token_hex(4)}@firma.ro"
    return db.execute("insert into auth.users (email) values (%s) returning id", (email,)).fetchone()[0]


@contextmanager
def as_user(db, user_id: uuid.UUID | None, *, keep: bool = False):
    """Runs the block the way Supabase runs a request from that user, then rolls back (unless keep)."""
    email = db.execute("select email from auth.users where id = %s", (user_id,)).fetchone()[0] if user_id else None
    with db.transaction(force_rollback=not keep):
        db.execute("set local role " + ("authenticated" if user_id else "anon"))
        db.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(user_id or ""),))
        claims = json.dumps({"sub": str(user_id), "email": email} if user_id else {})
        db.execute("select set_config('request.jwt.claims', %s, true)", (claims,))
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


# Organizations ------------------------------------------------------------------

PRINT = [0.01] * 1024


def run(db, user, sql, params=()):
    """One statement as the user, kept (setup for the checks that follow)."""
    with as_user(db, user, keep=True):
        cursor = db.execute(sql, params)
        return cursor.fetchone() if cursor.description else None


def new_org(db, admin, name="Fabrica de pâine") -> uuid.UUID:
    return run(db, admin, "select public.create_organization(%s)", (name,))[0]


def email_of(db, user) -> str:
    return db.execute("select email from auth.users where id = %s", (user,)).fetchone()[0]


def invite(db, admin, org, user, role="employee") -> uuid.UUID:
    return run(
        db, admin, "insert into public.org_invites (org_id, email, role) values (%s, %s, %s) returning id",
        (org, email_of(db, user), role),
    )[0]


def join(db, admin, org, user, role="employee"):
    run(db, user, "select public.accept_invite(%s)", (invite(db, admin, org, user, role),))


def company(db):
    """An organization with an admin and one employee."""
    admin, employee = new_user(db), new_user(db)
    org = new_org(db, admin)
    join(db, admin, org, employee)
    return org, admin, employee


def report(db, user, org, kind="fireAlarm") -> uuid.UUID:
    return run(db, user, "select public.report_alarm(%s, null, %s)", (org, kind))[0]


def answer(db, user, org, event, status="safe"):
    run(db, user, "insert into public.alarm_acks (event_id, org_id, user_id, status) values (%s, %s, %s, %s)",
        (event, org, user, status))


def test_creating_an_organization_makes_the_caller_its_admin(db):
    admin = new_user(db)
    new_org(db, admin)
    with as_user(db, admin):
        assert db.execute("select name from public.organizations").fetchall() == [("Fabrica de pâine",)]
        assert db.execute("select user_id, role from public.org_members").fetchall() == [(admin, "admin")]


def test_an_accepted_invite_brings_its_role_department_and_location(db):
    admin, worker = new_user(db), new_user(db)
    org = new_org(db, admin)
    hall = run(db, admin, "insert into public.org_locations (org_id, name) values (%s, 'Hala 2') returning id", (org,))[0]
    invite_id = run(
        db, admin,
        "insert into public.org_invites (org_id, email, department, location_id)"
        " values (%s, %s, 'Producție', %s) returning id",
        (org, email_of(db, worker), hall),
    )[0]
    with as_user(db, worker):
        # The invited person sees the invitation before accepting it.
        assert db.execute("select id from public.org_invites").fetchall() == [(invite_id,)]
    assert run(db, worker, "select public.accept_invite(%s)", (invite_id,))[0] == org
    with as_user(db, worker):
        row = db.execute("select role, department, location_id from public.org_members").fetchone()
        assert row == ("employee", "Producție", hall)


def test_organizations_cannot_see_each_other(db):
    org_a, admin_a, worker_a = company(db)
    _, admin_b, _ = company(db)
    run(db, worker_a, "insert into public.member_needs (org_id, user_id) values (%s, %s)", (org_a, worker_a))
    run(
        db, admin_a,
        "insert into public.org_location_sounds (org_id, label, model, fingerprint)"
        " values (%s, 'Alarma halei', 'tflite', %s)",
        (org_a, PRINT),
    )
    run(db, admin_a, "insert into public.org_locations (org_id, name) values (%s, 'Hala 2')", (org_a,))
    answer(db, worker_a, org_a, report(db, worker_a, org_a))
    invite(db, admin_a, org_a, new_user(db))

    with as_user(db, admin_b):
        for table in ("organizations", "org_members", "org_invites", "org_locations",
                      "member_needs", "org_location_sounds", "alarm_events", "alarm_acks"):
            column = "id" if table == "organizations" else "org_id"
            count = db.execute(f"select count(*) from public.{table} where {column} = %s", (org_a,)).fetchone()[0]
            assert count == 0, table


def test_employees_see_only_themselves_among_members(db):
    org, admin, worker = company(db)
    join(db, admin, org, new_user(db))
    with as_user(db, worker):
        assert db.execute("select user_id from public.org_members").fetchall() == [(worker,)]
    with as_user(db, admin):
        assert db.execute("select count(*) from public.org_members").fetchone()[0] == 3


@pytest.mark.parametrize("sql", [
    "insert into public.org_invites (org_id, email) values (%(org)s, 'nou@firma.ro')",
    "insert into public.org_locations (org_id, name) values (%(org)s, 'Hala 3')",
    "insert into public.org_location_sounds (org_id, label, model, fingerprint)"
    " values (%(org)s, 'x', 'tflite', %(print)s)",
])
def test_only_admins_invite_and_add_locations_and_sounds(db, sql):
    org, _, worker = company(db)
    with as_user(db, worker), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute(sql, {"org": org, "print": PRINT})


def test_an_invite_works_only_for_the_invited_email(db):
    org, admin, _ = company(db)
    invited, stranger = new_user(db), new_user(db)
    invite_id = invite(db, admin, org, invited)
    with as_user(db, stranger), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.accept_invite(%s)", (invite_id,))


def test_an_invite_works_once_and_not_after_it_expires(db):
    org, admin, _ = company(db)
    late, twice = new_user(db), new_user(db)
    expired = invite(db, admin, org, late)
    db.execute("update public.org_invites set expires_at = now() - interval '1 minute' where id = %s", (expired,))
    with as_user(db, late), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.accept_invite(%s)", (expired,))

    used = invite(db, admin, org, twice)
    run(db, twice, "select public.accept_invite(%s)", (used,))
    with as_user(db, twice), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.accept_invite(%s)", (used,))


def test_needs_are_written_by_the_employee_and_only_read_by_admins(db):
    org, admin, worker = company(db)
    run(
        db, worker,
        "insert into public.member_needs (org_id, user_id, watch_alerts, language) values (%s, %s, true, 'en')",
        (org, worker),
    )
    with as_user(db, admin):
        assert db.execute("select watch_alerts, language from public.member_needs").fetchall() == [(True, "en")]
        assert db.execute("update public.member_needs set watch_alerts = false").rowcount == 0
    with as_user(db, worker):
        assert db.execute("update public.member_needs set large_text = true").rowcount == 1


def test_an_admin_cannot_write_needs_for_an_employee(db):
    org, admin, worker = company(db)
    with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("insert into public.member_needs (org_id, user_id) values (%s, %s)", (org, worker))


def test_an_employee_cannot_change_their_own_role_or_place(db):
    _, _, worker = company(db)
    for change in ("role = 'admin'", "department = 'Conducere'"):
        with as_user(db, worker), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute(f"update public.org_members set {change} where user_id = %s", (worker,))
    with as_user(db, worker):
        assert db.execute(
            "update public.org_members set display_name = 'Ana' where user_id = %s", (worker,)
        ).rowcount == 1


def test_an_admin_manages_members_but_not_their_names(db):
    _, admin, worker = company(db)
    with as_user(db, admin):
        assert db.execute(
            "update public.org_members set department = 'Logistică' where user_id = %s", (worker,)
        ).rowcount == 1
    with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("update public.org_members set display_name = 'Altcineva' where user_id = %s", (worker,))


def test_the_last_admin_cannot_leave_or_be_demoted(db):
    _, admin, worker = company(db)
    with as_user(db, admin), pytest.raises(psycopg.errors.RaiseException):
        db.execute("delete from public.org_members where user_id = %s", (admin,))
    with as_user(db, admin), pytest.raises(psycopg.errors.RaiseException):
        db.execute("update public.org_members set role = 'employee' where user_id = %s", (admin,))

    run(db, admin, "update public.org_members set role = 'admin' where user_id = %s", (worker,))
    with as_user(db, admin):
        assert db.execute("delete from public.org_members where user_id = %s", (admin,)).rowcount == 1


def test_leaving_removes_needs_and_alarm_answers(db):
    org, _, worker = company(db)
    run(db, worker, "insert into public.member_needs (org_id, user_id) values (%s, %s)", (org, worker))
    answer(db, worker, org, report(db, worker, org))

    run(db, worker, "delete from public.org_members where user_id = %s", (worker,))
    assert db.execute("select count(*) from public.member_needs where user_id = %s", (worker,)).fetchone()[0] == 0
    assert db.execute("select count(*) from public.alarm_acks where user_id = %s", (worker,)).fetchone()[0] == 0


def test_deleting_the_account_of_a_last_admin_still_works(db):
    _, admin, _ = company(db)
    run(db, admin, "select public.delete_my_account()")
    assert db.execute("select count(*) from auth.users where id = %s", (admin,)).fetchone()[0] == 0


def test_an_alarm_reported_again_within_10_minutes_is_the_same_event(db):
    org, admin, worker = company(db)
    other = new_user(db)
    join(db, admin, org, other)
    first = report(db, worker, org)
    assert report(db, other, org) == first

    db.execute("update public.alarm_events set started_at = now() - interval '11 minutes' where id = %s", (first,))
    assert report(db, other, org) != first


def test_alarm_answers_each_employee_sees_their_own_admins_see_all(db):
    org, admin, worker = company(db)
    other = new_user(db)
    join(db, admin, org, other)
    event = report(db, worker, org, "siren")
    answer(db, worker, org, event, "safe")
    answer(db, other, org, event, "need_help")

    with as_user(db, worker):
        assert db.execute("select user_id, status from public.alarm_acks").fetchall() == [(worker, "safe")]
        assert db.execute("update public.alarm_events set ended_at = now()").rowcount == 0
    with as_user(db, admin):
        assert db.execute("select count(*) from public.alarm_acks where event_id = %s", (event,)).fetchone()[0] == 2
        assert db.execute("update public.alarm_events set ended_at = now() where id = %s", (event,)).rowcount == 1


def test_outsiders_cannot_report_or_answer_an_alarm(db):
    org, _, worker = company(db)
    event = report(db, worker, org)
    stranger = new_user(db)
    with as_user(db, stranger), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("insert into public.alarm_acks (event_id, org_id, user_id, status) values (%s, %s, %s, 'safe')",
                   (event, org, stranger))
    with as_user(db, stranger), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.report_alarm(%s, null, 'fireAlarm')", (org,))


def test_a_location_sound_needs_a_full_fingerprint_and_a_location_of_the_same_company(db):
    org_a, admin_a, _ = company(db)
    org_b, admin_b, _ = company(db)
    hall_b = run(db, admin_b, "insert into public.org_locations (org_id, name) values (%s, 'Hala B') returning id",
                 (org_b,))[0]
    sql = ("insert into public.org_location_sounds (org_id, location_id, label, model, fingerprint)"
           " values (%s, %s, 'Alarma', 'tflite', %s)")
    with as_user(db, admin_a), pytest.raises(psycopg.errors.CheckViolation):
        db.execute(sql, (org_a, None, [0.1, 0.2]))
    with as_user(db, admin_a), pytest.raises(psycopg.errors.ForeignKeyViolation):
        db.execute(sql, (org_a, hall_b, PRINT))


def test_signed_out_requests_see_no_organization_data(db):
    company(db)
    for table in ("organizations", "org_members", "member_needs", "alarm_events"):
        with as_user(db, None), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute(f"select * from public.{table}")
