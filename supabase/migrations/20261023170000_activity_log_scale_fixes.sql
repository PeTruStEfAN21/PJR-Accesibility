-- Echo: the activity log and the alarms at scale, found by a review on 100k-1M rows.
-- 1. Retention stays in the database (the server's daily purge runs only with
--    AUDIT_DATABASE_URL), but each write now clears at most 200 old rows, skipping rows
--    another transaction holds: a write never waits on someone else and never pays for a
--    big backlog. Reads already hide what is past 12 months; purge_activity_log() still
--    clears everything at once.
-- 2. Lines and summaries are checked with a subquery the planner can merge into the query,
--    not with a function called per row. The history pages through the company's link
--    table, in its index order.
-- 3. An employee cannot flood the company history: reporting the same open alarm again is
--    written once per person, and a closed alarm takes no more answers.
-- 4. Who started an alarm, sent an invitation or shared a sound is not readable from the
--    app (the app never asks for it); every other column stays readable.
-- (Row Level Security on activity_log and activity_log_orgs is already on, since
--  20261023130000_close_internal_functions.)

-- 1. Bounded retention -------------------------------------------------------------------

create or replace function public.log_activity(
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
  -- Retention without depending on the server: a few of the oldest rows past 12 months
  -- per write (an empty index range scan almost always). Rows another transaction holds
  -- are skipped, not waited for; a later write takes them.
  delete from public.activity_log a
  where a.id in (
    select old.id from public.activity_log old
    where old.at < now() - interval '12 months'
    order by old.at
    limit 200
    for update skip locked
  );
  return entry;
end;
$$;

-- 2. Reads that scale ---------------------------------------------------------------------

drop policy "lines of own meetings" on public.meeting_lines;
create policy "lines of own meetings" on public.meeting_lines
  for all to authenticated
  using (meeting_id in (select m.id from public.meetings m where m.owner_id = (select auth.uid())))
  with check (meeting_id in (select m.id from public.meetings m where m.owner_id = (select auth.uid())));

drop policy "summaries of own meetings" on public.summaries;
create policy "summaries of own meetings" on public.summaries
  for all to authenticated
  using (meeting_id in (select m.id from public.meetings m where m.owner_id = (select auth.uid())))
  with check (meeting_id in (select m.id from public.meetings m where m.owner_id = (select auth.uid())));

-- Nothing else used it.
drop function public.owns_meeting(uuid);

create or replace function public.my_activity(before_id bigint default null, max_rows integer default 100)
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
    and a.id < coalesce(before_id, 9223372036854775807)
  order by a.id desc
  limit least(greatest(coalesce(max_rows, 100), 1), 500);
$$;

-- Filtered and ordered on the link table, so the scan walks activity_log_orgs_org
-- (org_id, entry_id desc) from the page's start instead of the whole log.
create or replace function public.company_activity(target_org uuid, before_id bigint default null, max_rows integer default 100)
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
    and o.entry_id < coalesce(before_id, 9223372036854775807)
  order by o.entry_id desc
  limit least(greatest(coalesce(max_rows, 100), 1), 500);
$$;

-- 3. No flooding of the company history -------------------------------------------------

create or replace function public.report_alarm(target_org uuid, target_location uuid, alarm_kind text) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  alarm uuid;
  event_kind text;
  opened boolean := false;
begin
  if not public.is_org_member(target_org) then
    raise exception 'not a member' using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtext(target_org::text || coalesce(target_location::text, '')));
  select e.id, e.kind into alarm, event_kind from public.alarm_events e
  where e.org_id = target_org
    and e.location_id is not distinct from target_location
    and e.ended_at is null
    and e.started_at > now() - interval '10 minutes'
  order by e.started_at desc
  limit 1;
  if alarm is null then
    insert into public.alarm_events (org_id, location_id, kind)
    values (target_org, target_location, alarm_kind)
    returning id, kind into alarm, event_kind;
    opened := true;
  end if;
  -- Once per person and alarm: every phone in the room reports the same alarm many times.
  -- The advisory lock above makes a second report by the same person see the first one.
  if opened or not exists (
    select 1 from public.activity_log a
    where a.actor_id = auth.uid() and a.event = 'org_alarm_reported' and a.ref = alarm::text
  ) then
    perform public.log_activity('org_alarm_reported', auth.uid(), array[target_org], alarm::text, p_kind => event_kind);
  end if;
  return alarm;
end;
$$;

-- A closed alarm's roll call is over. The alarm row is locked (shared) so that an answer and
-- the closing never cross: the closing waits for the answer, or the answer sees it closed.
create function public.guard_alarm_answer() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ended timestamptz;
begin
  select e.ended_at into ended from public.alarm_events e where e.id = new.event_id for share;
  if ended is not null then
    raise exception 'the alarm is closed' using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger alarm_acks_open_alarm before insert or update on public.alarm_acks
  for each row execute function public.guard_alarm_answer();

revoke execute on function public.guard_alarm_answer() from public, anon, authenticated;

-- 4. Who did it stays out of the app -----------------------------------------------------
-- Column grants: a column added later is not readable until a migration grants it.

revoke select on public.alarm_events, public.org_invites, public.org_location_sounds from authenticated;
grant select (id, org_id, location_id, kind, started_at, ended_at) on public.alarm_events to authenticated;
grant select (id, org_id, email, role, department, location_id, experience, created_at, expires_at, accepted_at)
  on public.org_invites to authenticated;
grant select (id, org_id, location_id, label, level, model, fingerprint, created_at)
  on public.org_location_sounds to authenticated;
