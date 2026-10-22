"""The Supabase migrations on a real PostgreSQL: schema, Row Level Security, search, deletion.

Needs TEST_DATABASE_URL pointing at a server where we may create databases, e.g.
postgresql://postgres@localhost:5432/postgres. Skipped otherwise.
"""

import json
import os
import secrets
import threading
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
    email = email_of(db, admin)
    with as_user(db, admin):
        assert db.execute("select name from public.organizations").fetchall() == [("Fabrica de pâine",)]
        assert db.execute("select user_id, role, email from public.org_members").fetchall() == [
            (admin, "admin", email)
        ]


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
    email = email_of(db, worker)
    with as_user(db, worker):
        row = db.execute("select role, department, location_id, email from public.org_members").fetchone()
        assert row == ("employee", "Producție", hall, email)


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


@contextmanager
def needs_an_admin():
    """The error the app recognizes: the organization would be left without an admin."""
    with pytest.raises(psycopg.Error) as error:
        yield
    assert error.value.sqlstate == "EA001"


def test_the_last_admin_cannot_leave_or_be_demoted(db):
    _, admin, worker = company(db)
    with as_user(db, admin), needs_an_admin():
        db.execute("delete from public.org_members where user_id = %s", (admin,))
    with as_user(db, admin), needs_an_admin():
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


def test_the_last_admin_of_a_company_with_employees_cannot_delete_their_account(db):
    org, admin, worker = company(db)
    with as_user(db, admin), needs_an_admin():
        db.execute("select public.delete_my_account()")

    # With another admin in place, the account goes and the company stays.
    run(db, admin, "update public.org_members set role = 'admin' where user_id = %s", (worker,))
    run(db, admin, "select public.delete_my_account()")
    assert db.execute("select count(*) from auth.users where id = %s", (admin,)).fetchone()[0] == 0
    assert db.execute("select count(*) from public.organizations where id = %s", (org,)).fetchone()[0] == 1


def test_an_admin_deletes_the_company_with_everything_in_it(db):
    org, admin, worker = company(db)
    run(db, worker, "insert into public.member_needs (org_id, user_id) values (%s, %s)", (org, worker))
    answer(db, worker, org, report(db, worker, org))
    with as_user(db, worker), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.delete_organization(%s)", (org,))
    # Only through the function, which locks in the same order as everything else.
    with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("delete from public.organizations where id = %s", (org,))
    run(db, admin, "select public.delete_organization(%s)", (org,))
    assert db.execute("select count(*) from public.organizations where id = %s", (org,)).fetchone()[0] == 0
    for table in ("org_members", "member_needs", "alarm_events", "alarm_acks"):
        assert db.execute(f"select count(*) from public.{table} where org_id = %s", (org,)).fetchone()[0] == 0, table


def test_an_operator_can_still_delete_the_account_of_a_last_admin(db):
    _, admin, _ = company(db)
    db.execute("delete from auth.users where id = %s", (admin,))
    assert db.execute("select count(*) from auth.users where id = %s", (admin,)).fetchone()[0] == 0


def test_a_company_with_nobody_left_is_deleted(db):
    alone = new_user(db)
    org = new_org(db, alone)
    run(db, alone, "select public.delete_my_account()")
    assert db.execute("select count(*) from public.organizations where id = %s", (org,)).fetchone()[0] == 0

    founder = new_user(db)
    org = new_org(db, founder)
    run(db, founder, "insert into public.org_locations (org_id, name) values (%s, 'Hala 1')", (org,))
    run(db, founder, "delete from public.org_members where user_id = %s", (founder,))
    assert db.execute("select count(*) from public.organizations where id = %s", (org,)).fetchone()[0] == 0
    assert db.execute("select count(*) from public.org_locations where org_id = %s", (org,)).fetchone()[0] == 0


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


def test_the_invited_person_sees_the_company_name_before_joining(db):
    org, admin, _ = company(db)
    invited, stranger = new_user(db), new_user(db)
    invite_id = invite(db, admin, org, invited)
    with as_user(db, invited):
        rows = db.execute("select id, org_id, org_name, role from public.my_invites()").fetchall()
        assert rows == [(invite_id, org, "Fabrica de pâine", "employee")]
    with as_user(db, stranger):
        assert db.execute("select count(*) from public.my_invites()").fetchone()[0] == 0
    run(db, invited, "select public.accept_invite(%s)", (invite_id,))
    with as_user(db, invited):
        assert db.execute("select count(*) from public.my_invites()").fetchone()[0] == 0


def test_an_employee_can_change_their_answer(db):
    org, _, worker = company(db)
    event = report(db, worker, org)
    answer(db, worker, org, event, "safe")
    with as_user(db, worker):
        changed = db.execute(
            "update public.alarm_acks set status = 'need_help', acked_at = now() where event_id = %s and user_id = %s",
            (event, worker),
        ).rowcount
        assert changed == 1


def test_an_expired_invite_can_be_sent_again(db):
    org, admin, _ = company(db)
    late = new_user(db)
    expired = invite(db, admin, org, late)
    db.execute("update public.org_invites set expires_at = now() - interval '1 minute' where id = %s", (expired,))

    again = invite(db, admin, org, late)
    assert run(db, late, "select public.accept_invite(%s)", (again,))[0] == org
    assert db.execute("select count(*) from public.org_invites where id = %s", (expired,)).fetchone()[0] == 0


def test_an_open_invite_still_cannot_be_sent_twice(db):
    org, admin, _ = company(db)
    invited = new_user(db)
    invite(db, admin, org, invited)
    email = email_of(db, invited)
    with as_user(db, admin), pytest.raises(psycopg.errors.UniqueViolation):
        db.execute("insert into public.org_invites (org_id, email) values (%s, %s)", (org, email))


@pytest.mark.parametrize("sql", [
    "insert into public.org_invites (org_id, email, invited_by) values (%(org)s, 'a@firma.ro', %(other)s)",
    "insert into public.org_invites (org_id, email, expires_at)"
    " values (%(org)s, 'b@firma.ro', now() + interval '10 years')",
    "insert into public.org_invites (org_id, email, accepted_at) values (%(org)s, 'c@firma.ro', now())",
    "insert into public.org_location_sounds (org_id, label, model, fingerprint, created_by)"
    " values (%(org)s, 'x', 'tflite', %(print)s, %(other)s)",
    "update public.org_location_sounds set created_by = %(other)s",
    "insert into public.org_locations (org_id, name, created_at) values (%(org)s, 'Hala', now() - interval '1 year')",
])
def test_who_and_when_are_set_by_the_database_not_the_app(db, sql):
    org, admin, worker = company(db)
    with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute(sql, {"org": org, "other": worker, "print": PRINT})


def test_nobody_can_truncate_a_table(db):
    user = new_user(db)
    for table in ("meetings", "meeting_lines", "summaries", "profiles", "org_members", "alarm_acks"):
        with as_user(db, user), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute(f"truncate public.{table} cascade")


def test_nobody_moves_themselves_into_another_company(db):
    victim, _, _ = company(db)
    attacker = new_user(db)
    own = new_org(db, attacker, "A mea")
    with as_user(db, attacker), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("update public.org_members set org_id = %s where org_id = %s", (victim, own))


def test_an_admin_cannot_put_someone_else_in_a_members_place(db):
    org, admin, worker = company(db)
    stranger = new_user(db)
    with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("update public.org_members set user_id = %s where user_id = %s", (stranger, worker))


@pytest.mark.parametrize("who, sql", [
    ("admin", "update public.org_members set joined_at = '2000-01-01' where org_id = %(org)s"),
    ("admin", "update public.org_members set email = 'ceo@firma.ro' where org_id = %(org)s"),
    ("admin", "update public.alarm_events set started_at = '2000-01-01' where org_id = %(org)s"),
    ("admin", "update public.alarm_events set kind = 'siren' where org_id = %(org)s"),
    ("admin", "update public.organizations set created_at = '2000-01-01' where id = %(org)s"),
    ("worker", "insert into public.member_needs (org_id, user_id, updated_at) values (%(org)s, %(worker)s, '2000-01-01')"),
    ("worker", "update public.alarm_acks set event_id = event_id where org_id = %(org)s"),
    ("worker", "insert into public.profiles (id) values (gen_random_uuid())"),
    ("worker", "update public.profiles set created_at = '2000-01-01'"),
])
def test_only_the_columns_a_person_chooses_can_be_written(db, who, sql):
    org, admin, worker = company(db)
    report(db, worker, org)
    with as_user(db, admin if who == "admin" else worker), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute(sql, {"org": org, "worker": worker})


def test_the_app_saves_needs_the_way_it_does_with_an_upsert(db):
    org, _, worker = company(db)
    upsert = ("insert into public.member_needs (org_id, user_id, captions, visual_alerts, watch_alerts, large_text,"
              " language) values (%s, %s, true, true, %s, false, 'ro') on conflict (org_id, user_id) do update set"
              " org_id = excluded.org_id, user_id = excluded.user_id, captions = excluded.captions,"
              " visual_alerts = excluded.visual_alerts, watch_alerts = excluded.watch_alerts,"
              " large_text = excluded.large_text, language = excluded.language")
    run(db, worker, upsert, (org, worker, False))
    run(db, worker, upsert, (org, worker, True))
    assert db.execute("select watch_alerts from public.member_needs where user_id = %s", (worker,)).fetchone() == (True,)


def test_the_time_of_an_alarm_answer_is_the_servers(db):
    org, _, worker = company(db)
    event = report(db, worker, org)
    run(db, worker,
        "insert into public.alarm_acks (event_id, org_id, user_id, status, acked_at)"
        " values (%s, %s, %s, 'safe', now() - interval '1 hour')",
        (event, org, worker))
    run(db, worker,
        "update public.alarm_acks set status = 'need_help', acked_at = now() - interval '2 hours' where event_id = %s",
        (event,))
    age = db.execute("select now() - acked_at from public.alarm_acks where event_id = %s", (event,)).fetchone()[0]
    assert abs(age.total_seconds()) < 60


def test_a_closed_alarm_stays_closed_and_closes_at_the_servers_time(db):
    org, admin, worker = company(db)
    event = report(db, worker, org)
    # A phone clock running behind would otherwise end the alarm before it started.
    run(db, admin, "update public.alarm_events set ended_at = now() - interval '1 day' where id = %s", (event,))
    started, ended = db.execute("select started_at, ended_at from public.alarm_events where id = %s", (event,)).fetchone()
    assert ended >= started

    for change in ("ended_at = null", "ended_at = now() + interval '1 hour'"):
        with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute(f"update public.alarm_events set {change} where id = %s", (event,))


def race(db, first, second):
    """Runs first (left open), then second while first still holds its locks, then commits both.

    Each side is (user, sql, params). Returns the outcome of each: "ok" or the SQLSTATE.
    """
    url = psycopg.conninfo.make_conninfo(ADMIN_URL, dbname=db.info.dbname)
    outcomes = {}

    def step(conn, side, name):
        user, sql, params = side
        try:
            conn.execute("set local role authenticated")
            conn.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(user),))
            conn.execute(sql, params)
            conn.commit()
            outcomes[name] = "ok"
        except psycopg.Error as e:
            conn.rollback()
            outcomes[name] = e.sqlstate

    with psycopg.connect(url) as one, psycopg.connect(url) as two:
        user, sql, params = first
        one.execute("set local role authenticated")
        one.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(user),))
        one.execute(sql, params)
        thread = threading.Thread(target=step, args=(two, second, "second"))
        thread.start()
        thread.join(timeout=1.5)  # past deadlock_timeout (1 s), so a deadlock would already be reported
        waited = thread.is_alive()
        try:
            one.commit()
            outcomes["first"] = "ok"
        except psycopg.Error as e:
            outcomes["first"] = e.sqlstate
        thread.join(timeout=10)
    outcomes["waited"] = waited
    return outcomes


DEMOTE = "update public.org_members set role = 'employee' where org_id = %s and user_id = %s"


def test_two_admins_demoting_each_other_at_once_leave_one_admin(db):
    org, first, second = company(db)
    run(db, first, "update public.org_members set role = 'admin' where user_id = %s", (second,))

    outcome = race(db, (first, DEMOTE, (org, second)), (second, DEMOTE, (org, first)))

    assert outcome["waited"], "the second demotion should wait for the first"
    assert outcome["first"] == "ok" and outcome["second"] in ("EA001", "42501")
    admins = db.execute("select count(*) from public.org_members where org_id = %s and role = 'admin'", (org,))
    assert admins.fetchone()[0] == 1


@pytest.mark.parametrize("deleting_first", [True, False])
def test_deleting_a_company_while_someone_leaves_it_does_not_deadlock(db, deleting_first):
    org, admin, worker = company(db)
    delete = (admin, "select public.delete_organization(%s)", (org,))
    leave = (worker, "delete from public.org_members where org_id = %s and user_id = %s", (org, worker))

    outcome = race(db, *((delete, leave) if deleting_first else (leave, delete)))

    assert outcome["first"] == "ok" and outcome["second"] == "ok"
    assert db.execute("select count(*) from public.organizations where id = %s", (org,)).fetchone()[0] == 0


@pytest.mark.parametrize("deleting_first", [True, False])
def test_deleting_an_account_while_being_demoted_does_not_deadlock(db, deleting_first):
    org, first, second = company(db)
    run(db, first, "update public.org_members set role = 'admin' where user_id = %s", (second,))
    delete = (first, "select public.delete_my_account()", ())
    demote = (second, DEMOTE, (org, first))

    outcome = race(db, *((delete, demote) if deleting_first else (demote, delete)))

    assert "40P01" not in outcome.values()
    assert outcome["first"] == "ok" and outcome["second"] == "ok"
    assert db.execute("select count(*) from auth.users where id = %s", (first,)).fetchone()[0] == 0
    admins = db.execute("select user_id from public.org_members where org_id = %s and role = 'admin'", (org,))
    assert admins.fetchall() == [(second,)]


def test_an_admin_demoted_meanwhile_cannot_delete_the_company(db):
    org, first, second = company(db)
    run(db, first, "update public.org_members set role = 'admin' where user_id = %s", (second,))

    outcome = race(db, (second, DEMOTE, (org, first)), (first, "select public.delete_organization(%s)", (org,)))

    assert outcome["first"] == "ok" and outcome["second"] == "42501"
    assert db.execute("select count(*) from public.organizations where id = %s", (org,)).fetchone()[0] == 1


def test_two_people_in_the_same_two_companies_delete_their_accounts_at_once(db):
    url = psycopg.conninfo.make_conninfo(ADMIN_URL, dbname=db.info.dbname)
    for _ in range(10):
        # U runs O1 and works in O2; V the other way round; each company keeps another admin.
        u, v = new_user(db), new_user(db)
        o1, o1_admin, _ = company(db)
        o2, o2_admin, _ = company(db)
        join(db, o1_admin, o1, u, "admin")
        join(db, o1_admin, o1, v)
        join(db, o2_admin, o2, v, "admin")
        join(db, o2_admin, o2, u)

        barrier = threading.Barrier(2)
        outcomes = []

        def delete(user):
            with psycopg.connect(url) as conn:
                try:
                    conn.execute("set local role authenticated")
                    conn.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(user),))
                    barrier.wait()
                    conn.execute("select public.delete_my_account()")
                    conn.commit()
                    outcomes.append("ok")
                except psycopg.Error as e:
                    outcomes.append(e.sqlstate)

        threads = [threading.Thread(target=delete, args=(user,)) for user in (u, v)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=20)
        assert outcomes == ["ok", "ok"]


# Activity log ---------------------------------------------------------------------

def events_seen_by(db, user, org=None):
    """The events a user sees: their own history, or a company's when org is given."""
    with as_user(db, user):
        if org is None:
            rows = db.execute("select event from public.my_activity()").fetchall()
        else:
            rows = db.execute("select event from public.company_activity(%s)", (org,)).fetchall()
    return [r[0] for r in rows]


def as_audit(db, sql, params=()):
    """One statement as the server's audit role, kept."""
    with db.transaction():
        db.execute("set local role echo_audit")
        cursor = db.execute(sql, params)
        return cursor.fetchone() if cursor.description else None


def colleague_alarm(db, user, event="raised", alarm_id="a1", ip="203.0.113.7"):
    as_audit(
        db,
        "select public.record_colleague_alarm(%s, %s, 'fire', now(), 44.43, 26.10, 12, %s, %s, %s)",
        (event, alarm_id, user, email_of(db, user), ip),
    )


def test_a_colleague_alarm_is_in_the_authors_history_and_in_each_of_their_companies(db):
    org_a, admin_a, worker = company(db)
    org_b, admin_b, _ = company(db)
    join(db, admin_b, org_b, worker)
    outsider = new_user(db)
    colleague_alarm(db, worker)
    colleague_alarm(db, worker, "cancelled")

    both = ["colleague_alarm_cancelled", "colleague_alarm_raised"]
    assert events_seen_by(db, worker) == both
    assert events_seen_by(db, admin_a, org_a) == both
    assert events_seen_by(db, admin_b, org_b) == both
    assert events_seen_by(db, outsider) == []
    assert events_seen_by(db, outsider, org_a) == []


def test_an_employee_does_not_see_the_company_history(db):
    org, admin, worker = company(db)
    other = new_user(db)
    join(db, admin, org, other)
    colleague_alarm(db, other)
    assert events_seen_by(db, worker) == []
    assert events_seen_by(db, worker, org) == []


def test_nobody_reads_the_ip_from_the_app(db):
    _, admin, worker = company(db)
    colleague_alarm(db, worker)
    for user in (worker, admin):
        with as_user(db, user), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute("select ip from public.activity_log")
    with as_user(db, worker):
        columns = [c.name for c in db.execute("select * from public.my_activity()").description]
    assert "ip" not in columns
    # Kept for investigations, read by the operator only.
    ip = db.execute("select host(ip) from public.activity_log where actor_id = %s", (worker,)).fetchone()
    assert ip == ("203.0.113.7",)


@pytest.mark.parametrize("role", ["authenticated", "anon"])
def test_nobody_writes_or_changes_the_history_from_the_app(db, role):
    _, admin, worker = company(db)
    colleague_alarm(db, worker)
    user = admin if role == "authenticated" else None
    for sql in (
        "insert into public.activity_log (event) values ('colleague_alarm_raised')",
        "update public.activity_log set alarm_kind = 'siren'",
        "delete from public.activity_log",
        "insert into public.activity_log_orgs (entry_id, org_id) values (1, gen_random_uuid())",
        "select public.record_colleague_alarm('raised', 'x', 'fire', now(), 0, 0, 1, %(u)s, null, null)",
        "select public.purge_activity_log()",
    ):
        with as_user(db, user), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute(sql, {"u": worker})


@pytest.mark.parametrize("sql", [
    "select count(*) from public.activity_log",
    "select count(*) from public.meetings",
    "select count(*) from public.org_members",
    "delete from public.activity_log",
    "update public.activity_log set title = 'x'",
])
def test_the_audit_role_can_only_record_and_purge(db, sql):
    with db.transaction(force_rollback=True), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("set local role echo_audit")
        db.execute(sql)


def test_company_alarms_are_in_the_history(db):
    org, admin, worker = company(db)
    event = report(db, worker, org, "siren")
    answer(db, worker, org, event, "safe")
    run(db, worker, "update public.alarm_acks set status = 'need_help' where event_id = %s", (event,))
    run(db, worker, "update public.alarm_acks set status = 'need_help' where event_id = %s", (event,))  # no change
    run(db, admin, "update public.alarm_events set ended_at = now() where id = %s", (event,))

    assert events_seen_by(db, worker) == ["org_alarm_answered", "org_alarm_answered", "org_alarm_reported"]
    assert events_seen_by(db, admin, org) == [
        "org_alarm_closed", "org_alarm_answered", "org_alarm_answered", "org_alarm_reported",
    ]
    with as_user(db, admin):
        statuses = db.execute(
            "select status from public.company_activity(%s) where event = 'org_alarm_answered'", (org,)
        ).fetchall()
    assert statuses == [("need_help",), ("safe",)]


def company_meeting(db, owner, org, title="Ședința de vineri", lines=("Bună ziua",)) -> uuid.UUID:
    meeting = run(
        db, owner, "insert into public.meetings (lang, title, org_id) values ('ro-RO', %s, %s) returning id",
        (title, org),
    )[0]
    for seq, text in enumerate(lines, start=1):
        run(db, owner,
            "insert into public.meeting_lines (meeting_id, seq, caption_id, speaker, text, spoken_at)"
            " values (%s, %s, %s, 'coordinator', %s, now())", (meeting, seq, f"c{seq}", text))
    return meeting


def test_meetings_saved_for_the_company_are_in_its_history(db):
    org, admin, worker = company(db)
    meeting = company_meeting(db, worker, org)
    run(db, worker, "update public.meetings set ended_at = now() where id = %s", (meeting,))
    personal = run(db, worker, "insert into public.meetings (lang) values ('ro-RO') returning id")[0]
    run(db, worker, "delete from public.meetings where id = %s", (meeting,))

    assert events_seen_by(db, worker) == ["meeting_deleted", "meeting_started", "meeting_ended", "meeting_started"]
    # The personal meeting stays out of the company's history.
    assert events_seen_by(db, admin, org) == ["meeting_deleted", "meeting_ended", "meeting_started"]
    with as_user(db, admin):
        refs = {r[0] for r in db.execute("select ref from public.company_activity(%s)", (org,)).fetchall()}
    assert refs == {str(meeting)} and str(personal) not in refs


def test_a_meeting_can_only_be_saved_for_a_company_of_the_owner(db):
    org, _, _ = company(db)
    stranger = new_user(db)
    with as_user(db, stranger), pytest.raises(psycopg.errors.ForeignKeyViolation):
        db.execute("insert into public.meetings (lang, org_id) values ('ro-RO', %s)", (org,))


def test_the_company_of_a_meeting_cannot_be_changed_afterwards(db):
    org, _, worker = company(db)
    meeting = company_meeting(db, worker, org)
    with as_user(db, worker), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("update public.meetings set org_id = null where id = %s", (meeting,))


def test_an_admin_reads_a_company_meeting_and_the_employee_sees_it(db):
    org, admin, worker = company(db)
    worker_email, admin_email = email_of(db, worker), email_of(db, admin)
    meeting = company_meeting(db, worker, org, lines=("Bună ziua", "Raportul se trimite vineri"))
    run(db, worker, "insert into public.summaries (meeting_id, summary, lang) values (%s, 'Rezumat', 'ro')", (meeting,))

    with as_user(db, admin):
        listed = db.execute("select id, owner_email, title from public.company_meetings(%s)", (org,)).fetchall()
        assert listed == [(meeting, worker_email, "Ședința de vineri")]
        # Not directly: every reading goes through company_meeting(), which records it.
        count = db.execute("select count(*) from public.meeting_lines where meeting_id = %s", (meeting,))
        assert count.fetchone()[0] == 0
    content = run(db, admin, "select public.company_meeting(%s)", (meeting,))[0]
    assert [line["text"] for line in content["lines"]] == ["Bună ziua", "Raportul se trimite vineri"]
    assert content["summary"] == "Rezumat"

    with as_user(db, worker):
        row = db.execute(
            "select event, actor_email, title from public.my_activity() where event = 'meeting_read_by_admin'"
        ).fetchone()
    assert row == ("meeting_read_by_admin", admin_email, "Ședința de vineri")
    assert events_seen_by(db, admin, org)[0] == "meeting_read_by_admin"


def test_nobody_else_reads_a_company_meeting(db):
    org, admin, worker = company(db)
    colleague = new_user(db)
    join(db, admin, org, colleague)
    meeting = company_meeting(db, worker, org)
    personal = run(db, worker, "insert into public.meetings (lang) values ('ro-RO') returning id")[0]
    _, other_admin, _ = company(db)
    for user, target in ((colleague, meeting), (other_admin, meeting), (admin, personal)):
        with as_user(db, user), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute("select public.company_meeting(%s)", (target,))
    with as_user(db, colleague):
        assert db.execute("select count(*) from public.company_meetings(%s)", (org,)).fetchone()[0] == 0


def test_leaving_the_company_takes_the_meetings_away_but_keeps_the_history(db):
    org, admin, worker = company(db)
    meeting = company_meeting(db, worker, org)
    run(db, worker, "delete from public.org_members where user_id = %s", (worker,))

    assert db.execute("select org_id from public.meetings where id = %s", (meeting,)).fetchone() == (None,)
    with as_user(db, admin), pytest.raises(psycopg.errors.InsufficientPrivilege):
        db.execute("select public.company_meeting(%s)", (meeting,))
    assert events_seen_by(db, admin, org) == ["meeting_started"]


def test_deleting_the_account_keeps_alarms_and_removes_meetings(db):
    org, admin, worker = company(db)
    email = email_of(db, worker)
    colleague_alarm(db, worker)
    company_meeting(db, worker, org)
    answer(db, worker, org, report(db, worker, org))
    run(db, worker, "select public.delete_my_account()")

    rows = db.execute(
        "select event, actor_id from public.activity_log where actor_email = %s order by id", (email,)
    ).fetchall()
    assert [r[0] for r in rows] == ["colleague_alarm_raised", "org_alarm_reported", "org_alarm_answered"]
    assert all(r[1] is None for r in rows)
    seen = events_seen_by(db, admin, org)
    assert "colleague_alarm_raised" in seen and not any(e.startswith("meeting_") for e in seen)


def test_an_admin_who_deletes_their_account_stays_named_in_what_they_read(db):
    org, admin, worker = company(db)
    run(db, admin, "update public.org_members set role = 'admin' where user_id = %s", (worker,))
    admin_email = email_of(db, admin)
    meeting = company_meeting(db, worker, org)
    run(db, admin, "select public.company_meeting(%s)", (meeting,))
    run(db, admin, "select public.delete_my_account()")
    with as_user(db, worker):
        row = db.execute("select actor_email from public.my_activity() where event = 'meeting_read_by_admin'")
        assert row.fetchone() == (admin_email,)


def test_old_history_is_purged_after_12_months(db):
    _, _, worker = company(db)
    colleague_alarm(db, worker, alarm_id="old")
    colleague_alarm(db, worker, alarm_id="new")
    db.execute("update public.activity_log set at = now() - interval '13 months' where ref = 'old'")
    assert as_audit(db, "select public.purge_activity_log()")[0] == 1
    refs = db.execute("select ref from public.activity_log where actor_id = %s", (worker,)).fetchall()
    assert refs == [("new",)]


def test_nobody_moves_the_history_counter_from_the_app(db):
    user = new_user(db)
    for sql in ("select setval('public.activity_log_id_seq', 1, false)",
                "select nextval('public.activity_log_id_seq')"):
        with as_user(db, user), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute(sql)


def test_old_history_goes_even_without_the_server_and_is_never_shown(db):
    org, admin, worker = company(db)
    colleague_alarm(db, worker, alarm_id="old")
    db.execute("update public.activity_log set at = now() - interval '13 months' where ref = 'old'")
    # Not shown while it waits to be deleted.
    assert events_seen_by(db, worker) == []
    assert events_seen_by(db, admin, org) == []
    # Any new row clears what is past its time.
    report(db, worker, org)
    assert db.execute("select count(*) from public.activity_log where ref = 'old'").fetchone()[0] == 0


def test_the_server_cannot_date_a_row_in_the_future(db):
    _, _, worker = company(db)
    as_audit(db, "select public.record_colleague_alarm('raised', 'f', 'fire', now() + interval '50 years',"
                 " 0, 0, 1, %s, null, null)", (worker,))
    assert db.execute("select at <= now() from public.activity_log where ref = 'f'").fetchone() == (True,)


def test_an_ended_meeting_stays_ended_at_the_servers_time(db):
    org, admin, worker = company(db)
    meeting = company_meeting(db, worker, org)
    run(db, worker, "update public.meetings set ended_at = now() - interval '1 day' where id = %s", (meeting,))
    started, ended = db.execute("select started_at, ended_at from public.meetings where id = %s", (meeting,)).fetchone()
    assert ended >= started
    # Ending again or reopening changes nothing and logs nothing more.
    run(db, worker, "update public.meetings set ended_at = null where id = %s", (meeting,))
    run(db, worker, "update public.meetings set ended_at = now() where id = %s", (meeting,))
    assert db.execute("select ended_at from public.meetings where id = %s", (meeting,)).fetchone() == (ended,)
    assert events_seen_by(db, admin, org) == ["meeting_ended", "meeting_started"]


def test_reporting_an_open_alarm_logs_the_alarms_own_kind(db):
    org, admin, worker = company(db)
    report(db, worker, org, "fireAlarm")
    report(db, admin, org, "siren")  # same open alarm
    with as_user(db, admin):
        kinds = db.execute(
            "select alarm_kind from public.company_activity(%s) where event = 'org_alarm_reported'", (org,)
        ).fetchall()
    assert kinds == [("fireAlarm",), ("fireAlarm",)]


def test_new_functions_are_not_executable_by_everyone_by_default(db):
    db.execute("create function public.tmp_probe() returns int language sql as 'select 1'")
    try:
        with db.transaction(force_rollback=True), pytest.raises(psycopg.errors.InsufficientPrivilege):
            db.execute("set local role echo_audit")
            db.execute("select public.tmp_probe()")
    finally:
        db.execute("drop function public.tmp_probe()")
