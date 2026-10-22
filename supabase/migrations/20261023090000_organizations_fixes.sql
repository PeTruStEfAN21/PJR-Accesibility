-- Echo: fixes to organizations, found in review.
-- 0. Supabase grants anon and authenticated every privilege on new public tables; the
--    earlier migrations revoked them only from anon, so the column grants limited nothing
--    (a member could move their own admin row into another company). Now everything is
--    revoked first and only what a person actually chooses is granted back.
-- 1. An expired invitation no longer blocks inviting the same email again.
-- 2. A company is never left without an admin by an account deletion, and a company
--    with nobody left in it is deleted.
-- 3. Who did something and when is set by the database, never by the app.
-- 4. Two admins demoting each other at the same moment cannot both succeed.
-- 5. A closed alarm stays closed, and closes at the server's time.
--
-- EA001 is the error the app recognizes as "this organization needs an admin".
-- Lock order, everywhere: member rows (ordered by org, then user), then organization
-- rows (ordered by id). Row triggers run after their row is locked, so every other path
-- (account deletion, company deletion) takes the member rows first too.

-- 0 and 3. Privileges -------------------------------------------------------------------

revoke all on public.profiles, public.organizations, public.org_locations, public.org_members,
  public.org_invites, public.member_needs, public.org_location_sounds, public.alarm_events,
  public.alarm_acks
  from anon, authenticated;
-- Meetings keep their full read/write grants; truncate (which ignores RLS), references
-- and trigger were never meant for anyone.
revoke truncate, references, trigger on public.meetings, public.meeting_lines, public.summaries
  from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, settings) on public.profiles to authenticated;

-- Companies are created by create_organization() and deleted by delete_organization().
grant select on public.organizations to authenticated;
grant update (name) on public.organizations to authenticated;

grant select, delete on public.org_locations to authenticated;
grant insert (org_id, name) on public.org_locations to authenticated;
grant update (name) on public.org_locations to authenticated;

-- Memberships are created by accept_invite(); org_id and user_id never change.
grant select, delete on public.org_members to authenticated;
grant update (role, display_name, department, location_id) on public.org_members to authenticated;

grant select, delete on public.org_invites to authenticated;
grant insert (org_id, email, role, department, location_id) on public.org_invites to authenticated;

-- The app saves needs with an upsert, which updates every column it sends, keys included;
-- RLS and the foreign key keep the row on the employee's own membership.
grant select, delete on public.member_needs to authenticated;
grant insert (org_id, user_id, captions, visual_alerts, watch_alerts, large_text, language)
  on public.member_needs to authenticated;
grant update (org_id, user_id, captions, visual_alerts, watch_alerts, large_text, language)
  on public.member_needs to authenticated;

grant select, delete on public.org_location_sounds to authenticated;
grant insert (org_id, location_id, label, level, model, fingerprint) on public.org_location_sounds to authenticated;
grant update (location_id, label, level) on public.org_location_sounds to authenticated;

-- Alarms are opened by report_alarm().
grant select on public.alarm_events to authenticated;
grant update (ended_at) on public.alarm_events to authenticated;

-- acked_at stays writable so that app versions which still send it keep working;
-- a trigger below replaces whatever they send.
grant select on public.alarm_acks to authenticated;
grant insert (event_id, org_id, user_id, status, acked_at) on public.alarm_acks to authenticated;
grant update (status, acked_at) on public.alarm_acks to authenticated;

-- 1. Expired invitations ---------------------------------------------------------------
-- The unique index on open invitations cannot look at the clock, so a new invitation
-- replaces an expired one for the same email first.

create function public.replace_expired_invite() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.org_invites i
  where i.org_id = new.org_id
    and i.email = new.email
    and i.accepted_at is null
    and i.expires_at <= now();
  return new;
end;
$$;

create trigger org_invites_replace_expired before insert on public.org_invites
  for each row execute function public.replace_expired_invite();

-- 2 and 4. Keeping an admin ------------------------------------------------------------

create or replace function public.keep_an_admin() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'admin'
     and (tg_op = 'DELETE' or new.role <> 'admin')
     -- Deleting an account always works; delete_my_account() checks this case first.
     and exists (select 1 from auth.users u where u.id = old.user_id) then
    -- One change of admins at a time per organization: two admins demoting each other
    -- at once would otherwise both still see the other one in charge. The lock also
    -- tells whether the organization is still there (it is not while it is being deleted).
    perform 1 from public.organizations o where o.id = old.org_id for no key update;
    if found
       and not exists (
         select 1 from public.org_members m
         where m.org_id = old.org_id and m.role = 'admin' and m.user_id <> old.user_id
       )
       -- The last person in a company may leave it: the company goes with them.
       and (tg_op = 'UPDATE' or exists (
         select 1 from public.org_members m where m.org_id = old.org_id and m.user_id <> old.user_id
       )) then
      raise exception 'an organization needs at least one admin' using errcode = 'EA001';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- A company with nobody left in it is deleted, with its locations, sounds and alarms.
create function public.drop_empty_organization() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- "for update" waits for anyone joining right now (their insert holds a key share on
  -- the company), so a newcomer is never deleted along with a company they just joined.
  perform 1 from public.organizations o where o.id = old.org_id for update;
  if found and not exists (select 1 from public.org_members m where m.org_id = old.org_id) then
    delete from public.organizations o where o.id = old.org_id;
  end if;
  return null;
end;
$$;

create trigger org_members_drop_empty after delete on public.org_members
  for each row execute function public.drop_empty_organization();

-- The last admin of a company that still has other people in it makes someone else
-- admin first; otherwise those people would be left with nobody to manage the company.
create or replace function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  -- Own memberships first: nobody can promote or demote the caller meanwhile.
  perform 1 from public.org_members me where me.user_id = auth.uid() order by me.org_id for update;
  -- Then every company they are in, in order: no other admin can step down meanwhile,
  -- and the cascade below (drop_empty_organization) only takes locks already held here.
  perform 1 from public.organizations o
  where o.id in (select me.org_id from public.org_members me where me.user_id = auth.uid())
  order by o.id
  for update;
  if exists (
    select 1 from public.org_members me
    where me.user_id = auth.uid()
      and me.role = 'admin'
      and not exists (
        select 1 from public.org_members m
        where m.org_id = me.org_id and m.role = 'admin' and m.user_id <> me.user_id
      )
      and exists (select 1 from public.org_members m where m.org_id = me.org_id and m.user_id <> me.user_id)
  ) then
    raise exception 'make someone else admin of your organization first' using errcode = 'EA001';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- Deletes a company with everything in it. A function rather than a plain delete so that
-- the member rows are locked before the company, in the same order as everywhere else.
create function public.delete_organization(target uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_org_admin(target) then
    raise exception 'only an admin can delete the organization' using errcode = 'insufficient_privilege';
  end if;
  perform 1 from public.org_members m where m.org_id = target order by m.user_id for update;
  -- Asked again: the caller may have been demoted while this waited for the locks.
  if not public.is_org_admin(target) then
    raise exception 'only an admin can delete the organization' using errcode = 'insufficient_privilege';
  end if;
  delete from public.organizations o where o.id = target;
end;
$$;

-- 3. The time of an alarm answer -------------------------------------------------------

create function public.stamp_alarm_ack() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.acked_at := now();
  return new;
end;
$$;

create trigger alarm_acks_stamp before insert or update on public.alarm_acks
  for each row execute function public.stamp_alarm_ack();

-- 5. Closing an alarm ------------------------------------------------------------------
-- Closing is final and happens now, whatever time the phone sends: a phone clock
-- running behind would otherwise end the alarm before it started.
create function public.guard_alarm_close() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.ended_at is not distinct from old.ended_at then
    return new;
  end if;
  if old.ended_at is not null then
    raise exception 'a closed alarm stays closed' using errcode = 'insufficient_privilege';
  end if;
  new.ended_at := now();
  return new;
end;
$$;

create trigger alarm_events_close before update on public.alarm_events
  for each row execute function public.guard_alarm_close();

-- Functions ------------------------------------------------------------------------------

revoke execute on function public.replace_expired_invite(), public.drop_empty_organization(),
  public.stamp_alarm_ack(), public.guard_alarm_close(), public.delete_organization(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_organization(uuid) to authenticated;
