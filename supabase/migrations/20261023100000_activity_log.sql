-- Echo: the activity log. What happens with alarms and meetings stays written down:
-- each person sees their own history, a company's admins see the company's.
-- Design: docs/superpowers/specs/2026-10-23-istoric-activitate-design.md
--
-- GDPR: fixed columns, no free text; the IP is never returned to the app (it stays for
-- investigations, read by the operator only); rows go after 12 months; deleting an
-- account removes its meeting rows and keeps its alarm rows without the account link
-- (art. 17(3)(e)). Nobody, admins included, can change or delete a row from the app.
-- Rows are written by the database itself (triggers, functions) and, for colleague
-- alarms, by the server through the echo_audit role, which can do nothing else.

create type public.activity_event as enum (
  'colleague_alarm_raised', 'colleague_alarm_cancelled',
  'org_alarm_reported', 'org_alarm_answered', 'org_alarm_closed',
  'meeting_started', 'meeting_ended', 'meeting_deleted', 'meeting_read_by_admin'
);

-- Tables ------------------------------------------------------------------------

create table public.activity_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  event public.activity_event not null,
  -- Who did it. No foreign key: alarm rows outlive the account (see forget_user_activity).
  actor_id uuid,
  actor_email text check (char_length(actor_email) <= 320),
  -- Whose meeting an admin read.
  subject_user_id uuid,
  subject_email text check (char_length(subject_email) <= 320),
  -- The alarm, alarm event or meeting the row is about.
  ref text check (char_length(ref) <= 64),
  title text check (char_length(title) <= 200),
  alarm_kind text check (alarm_kind ~ '^[A-Za-z]{1,32}$'),
  status public.ack_status,
  lat double precision check (lat between -90 and 90),
  lon double precision check (lon between -180 and 180),
  accuracy_m real check (accuracy_m >= 0),
  ip inet
);

create index activity_log_actor on public.activity_log (actor_id, id desc);
create index activity_log_subject on public.activity_log (subject_user_id, id desc) where subject_user_id is not null;
create index activity_log_at on public.activity_log (at);

-- The companies whose admins see a row; gone with the company.
create table public.activity_log_orgs (
  entry_id bigint not null references public.activity_log (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  primary key (entry_id, org_id)
);

create index activity_log_orgs_org on public.activity_log_orgs (org_id, entry_id desc);

-- A meeting saved for a company: its admins can read it. Only for a company the owner is
-- in; leaving the company takes the meeting away from it. Set once, when the meeting starts.
alter table public.meetings add column org_id uuid;
alter table public.meetings
  add foreign key (org_id, owner_id) references public.org_members (org_id, user_id) on delete set null (org_id);
create index meetings_org on public.meetings (org_id, started_at desc) where org_id is not null;

-- Writing ----------------------------------------------------------------------------

create function public.log_activity(
  p_event public.activity_event,
  p_actor uuid,
  p_orgs uuid[] default '{}',
  p_ref text default null,
  p_title text default null,
  p_subject uuid default null,
  p_kind text default null,
  p_status public.ack_status default null,
  p_lat double precision default null,
  p_lon double precision default null,
  p_accuracy real default null,
  p_ip inet default null,
  p_email text default null,
  p_at timestamptz default null
) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  entry bigint;
begin
  insert into public.activity_log
    (at, event, actor_id, actor_email, subject_user_id, subject_email, ref, title, alarm_kind, status,
     lat, lon, accuracy_m, ip)
  values (
    least(coalesce(p_at, now()), now()), p_event, p_actor,
    coalesce(p_email, (select u.email from auth.users u where u.id = p_actor)),
    p_subject, (select u.email from auth.users u where u.id = p_subject),
    p_ref, left(p_title, 200), p_kind, p_status, p_lat, p_lon, p_accuracy, p_ip
  )
  returning id into entry;
  insert into public.activity_log_orgs (entry_id, org_id)
  select distinct entry, o from unnest(p_orgs) as o where o is not null;
  -- Retention without depending on the server: every write clears what is past 12 months
  -- (an index range scan that is empty almost always).
  delete from public.activity_log a where a.at < now() - interval '12 months';
  return entry;
end;
$$;

-- Meetings: started, ended, deleted. Lines are not logged (too many, and the meeting is).
create function public.log_meeting_activity() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_activity('meeting_started', new.owner_id, array[new.org_id], new.id::text, new.title);
  elsif tg_op = 'UPDATE' then
    if old.ended_at is null and new.ended_at is not null then
      perform public.log_activity('meeting_ended', new.owner_id, array[new.org_id], new.id::text, new.title);
    end if;
  -- A meeting deleted with its owner's account leaves no trace (see forget_user_activity).
  elsif exists (select 1 from auth.users u where u.id = old.owner_id) then
    perform public.log_activity('meeting_deleted', old.owner_id, array[old.org_id], old.id::text, old.title);
  end if;
  return null;
end;
$$;

create trigger meetings_log after insert or update or delete on public.meetings
  for each row execute function public.log_meeting_activity();

-- Ending a meeting is final and happens at the server's time: the phone's clock does not
-- date the company's records, and ending again (or reopening) changes nothing.
create function public.keep_meeting_end() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.ended_at is distinct from old.ended_at then
    new.ended_at := case when old.ended_at is null then now() else old.ended_at end;
  end if;
  return new;
end;
$$;

create trigger meetings_keep_end before update on public.meetings
  for each row execute function public.keep_meeting_end();

-- Company alarms: reported (in report_alarm), answered, closed.
create or replace function public.report_alarm(target_org uuid, target_location uuid, alarm_kind text) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event uuid;
  event_kind text;
begin
  if not public.is_org_member(target_org) then
    raise exception 'not a member' using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtext(target_org::text || coalesce(target_location::text, '')));
  select e.id, e.kind into event, event_kind from public.alarm_events e
  where e.org_id = target_org
    and e.location_id is not distinct from target_location
    and e.ended_at is null
    and e.started_at > now() - interval '10 minutes'
  order by e.started_at desc
  limit 1;
  if event is null then
    insert into public.alarm_events (org_id, location_id, kind)
    values (target_org, target_location, alarm_kind)
    returning id, kind into event, event_kind;
  end if;
  perform public.log_activity('org_alarm_reported', auth.uid(), array[target_org], event::text, p_kind => event_kind);
  return event;
end;
$$;

create function public.log_alarm_answer() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.status = old.status then
    return null;
  end if;
  perform public.log_activity(
    'org_alarm_answered', new.user_id, array[new.org_id], new.event_id::text,
    p_kind => (select e.kind from public.alarm_events e where e.id = new.event_id),
    p_status => new.status
  );
  return null;
end;
$$;

create trigger alarm_acks_log after insert or update on public.alarm_acks
  for each row execute function public.log_alarm_answer();

create function public.log_alarm_close() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.ended_at is null and new.ended_at is not null then
    perform public.log_activity('org_alarm_closed', auth.uid(), array[new.org_id], new.id::text, p_kind => new.kind);
  end if;
  return null;
end;
$$;

create trigger alarm_events_log after update on public.alarm_events
  for each row execute function public.log_alarm_close();

-- Colleague alarms: only the server knows who raised them and from which address.
create function public.record_colleague_alarm(
  p_event text, p_alarm_id text, p_kind text, p_at timestamptz,
  p_lat double precision, p_lon double precision, p_accuracy real,
  p_user uuid, p_email text, p_ip inet
) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event not in ('raised', 'cancelled') then
    raise exception 'unknown alarm event %', p_event;
  end if;
  return public.log_activity(
    case p_event when 'raised' then 'colleague_alarm_raised' else 'colleague_alarm_cancelled' end::public.activity_event,
    p_user,
    array(select m.org_id from public.org_members m where m.user_id = p_user),
    p_alarm_id, null, null, p_kind, null, p_lat, p_lon, p_accuracy, p_ip, p_email, p_at
  );
end;
$$;

-- Forgetting ---------------------------------------------------------------------------

-- A deleted account takes its meeting rows with it; alarm rows stay, without the account.
create function public.forget_user_activity() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_log a
  where (a.actor_id = old.id and a.event in ('meeting_started', 'meeting_ended', 'meeting_deleted'))
     or (a.subject_user_id = old.id and a.event = 'meeting_read_by_admin');
  update public.activity_log a set actor_id = null where a.actor_id = old.id;
  return null;
end;
$$;

create trigger on_auth_user_deleted_forget_activity after delete on auth.users
  for each row execute function public.forget_user_activity();

create function public.purge_activity_log() returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  gone integer;
begin
  delete from public.activity_log a where a.at < now() - interval '12 months';
  get diagnostics gone = row_count;
  return gone;
end;
$$;

-- Reading --------------------------------------------------------------------------------
-- The app reads the log only through these: never the IP, never someone else's rows.

create function public.my_activity(before_id bigint default null, max_rows integer default 100)
returns table (
  id bigint, at timestamptz, event public.activity_event, actor_id uuid, actor_email text,
  subject_user_id uuid, subject_email text, ref text, title text, alarm_kind text,
  status public.ack_status, lat double precision, lon double precision, accuracy_m real
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.at, a.event, a.actor_id, a.actor_email, a.subject_user_id, a.subject_email, a.ref, a.title,
         a.alarm_kind, a.status, a.lat, a.lon, a.accuracy_m
  from public.activity_log a
  where (select auth.uid()) is not null
    and (a.actor_id = (select auth.uid()) or a.subject_user_id = (select auth.uid()))
    and a.at >= now() - interval '12 months'
    and (before_id is null or a.id < before_id)
  order by a.id desc
  limit least(greatest(coalesce(max_rows, 100), 1), 500);
$$;

create function public.company_activity(target_org uuid, before_id bigint default null, max_rows integer default 100)
returns table (
  id bigint, at timestamptz, event public.activity_event, actor_id uuid, actor_email text,
  subject_user_id uuid, subject_email text, ref text, title text, alarm_kind text,
  status public.ack_status, lat double precision, lon double precision, accuracy_m real
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.at, a.event, a.actor_id, a.actor_email, a.subject_user_id, a.subject_email, a.ref, a.title,
         a.alarm_kind, a.status, a.lat, a.lon, a.accuracy_m
  from public.activity_log_orgs o
  join public.activity_log a on a.id = o.entry_id
  where o.org_id = target_org
    and public.is_org_admin(target_org)
    and a.at >= now() - interval '12 months'
    and (before_id is null or a.id < before_id)
  order by a.id desc
  limit least(greatest(coalesce(max_rows, 100), 1), 500);
$$;

-- Company meetings: listed freely for its admins, read only through company_meeting(),
-- which writes the reading into the employee's history first.
create function public.company_meetings(target_org uuid)
returns table (id uuid, owner_id uuid, owner_email text, title text, started_at timestamptz, ended_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.owner_id, om.email, m.title, m.started_at, m.ended_at
  from public.meetings m
  join public.org_members om on om.org_id = m.org_id and om.user_id = m.owner_id
  where m.org_id = target_org and public.is_org_admin(target_org)
  order by m.started_at desc
  limit 500;
$$;

create function public.company_meeting(meeting uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  found public.meetings;
begin
  select * into found from public.meetings m where m.id = meeting;
  if found.id is null or found.org_id is null or not public.is_org_admin(found.org_id) then
    raise exception 'not a meeting of your company' using errcode = 'insufficient_privilege';
  end if;
  if found.owner_id <> auth.uid() then
    perform public.log_activity('meeting_read_by_admin', auth.uid(), array[found.org_id], found.id::text,
                                found.title, found.owner_id);
  end if;
  return jsonb_build_object(
    'id', found.id,
    'title', found.title,
    'lang', found.lang,
    'started_at', found.started_at,
    'ended_at', found.ended_at,
    'owner_email', (select om.email from public.org_members om
                    where om.org_id = found.org_id and om.user_id = found.owner_id),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object('seq', l.seq, 'speaker', l.speaker, 'text', l.text, 'spoken_at', l.spoken_at)
                       order by l.seq)
      from public.meeting_lines l where l.meeting_id = found.id
    ), '[]'::jsonb),
    'summary', (select s.summary from public.summaries s where s.meeting_id = found.id),
    'tasks', (select s.tasks from public.summaries s where s.meeting_id = found.id)
  );
end;
$$;

-- Privileges ------------------------------------------------------------------------------

revoke all on public.activity_log, public.activity_log_orgs from public, anon, authenticated;
-- The identity's sequence too: whoever can move it can make every write to the log fail.
revoke all on sequence public.activity_log_id_seq from public, anon, authenticated;

-- Postgres lets PUBLIC execute every new function; from now on a function is callable only
-- by the roles its migration grants it to (Supabase's own grants to anon/authenticated stay).
alter default privileges revoke execute on functions from public;

-- org_id is chosen once, when the meeting starts; the owner then only renames or ends it.
revoke insert, update on public.meetings from authenticated;
grant insert (lang, session_code, title, org_id) on public.meetings to authenticated;
grant update (title, ended_at) on public.meetings to authenticated;

revoke execute on function
  public.log_activity(public.activity_event, uuid, uuid[], text, text, uuid, text, public.ack_status,
                      double precision, double precision, real, inet, text, timestamptz),
  public.log_meeting_activity(), public.keep_meeting_end(), public.log_alarm_answer(), public.log_alarm_close(),
  public.record_colleague_alarm(text, text, text, timestamptz, double precision, double precision, real, uuid, text, inet),
  public.forget_user_activity(), public.purge_activity_log(),
  public.my_activity(bigint, integer), public.company_activity(uuid, bigint, integer),
  public.company_meetings(uuid), public.company_meeting(uuid)
  from public, anon, authenticated;

grant execute on function
  public.my_activity(bigint, integer), public.company_activity(uuid, bigint, integer),
  public.company_meetings(uuid), public.company_meeting(uuid)
  to authenticated;

-- The server's role: records colleague alarms and purges old rows, nothing else.
-- Created without a password; an installation enables it with
--   alter role echo_audit with login password '…';
-- and puts the connection string in AUDIT_DATABASE_URL.
do $$
begin
  if not exists (select from pg_roles where rolname = 'echo_audit') then
    create role echo_audit nologin;
  end if;
end
$$;

grant usage on schema public to echo_audit;
grant execute on function
  public.record_colleague_alarm(text, text, text, timestamptz, double precision, double precision, real, uuid, text, inet),
  public.purge_activity_log()
  to echo_audit;
