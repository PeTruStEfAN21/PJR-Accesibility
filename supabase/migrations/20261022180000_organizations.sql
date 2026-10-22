-- Echo: organizations. A company invites its deaf and hard-of-hearing employees,
-- sees the accessibility needs each of them chooses to share, shares the sounds of
-- its locations and, during a critical alarm, sees who confirmed they are safe.
-- Needs, not diagnoses: no column holds medical details (GDPR art. 9).
-- The same schema runs on our Supabase or on one installed at the company.

create type public.org_role as enum ('admin', 'employee');
create type public.alert_level as enum ('critical', 'warning', 'info');
-- Fingerprints from the phone (TFLite) and the browser (TF.js) do not match each other.
create type public.sound_model as enum ('tflite', 'tfjs');
create type public.ack_status as enum ('safe', 'need_help');

-- Tables ------------------------------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.org_locations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  created_at timestamptz not null default now(),
  -- Lets other tables require a location of the same organization.
  unique (org_id, id)
);

create table public.org_members (
  org_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.org_role not null default 'employee',
  display_name text check (char_length(display_name) <= 100),
  department text check (char_length(department) <= 100),
  location_id uuid,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, user_id),
  foreign key (org_id, location_id) references public.org_locations (org_id, id) on delete set null (location_id)
);

create index org_members_user on public.org_members (user_id);

-- An employee joins only by accepting: nobody is put in a company without knowing.
create table public.org_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  email text not null check (email = lower(email) and char_length(email) between 3 and 320 and position('@' in email) > 1),
  role public.org_role not null default 'employee',
  department text check (char_length(department) <= 100),
  location_id uuid,
  invited_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  accepted_at timestamptz,
  foreign key (org_id, location_id) references public.org_locations (org_id, id) on delete set null (location_id)
);

create unique index org_invites_open on public.org_invites (org_id, email) where accepted_at is null;
create index org_invites_email on public.org_invites (email);

-- What the employee chooses to share. Written only by them; read by them and the admins.
create table public.member_needs (
  org_id uuid not null,
  user_id uuid not null,
  captions boolean not null default true,
  visual_alerts boolean not null default true,
  watch_alerts boolean not null default false,
  large_text boolean not null default false,
  language text not null default 'ro' check (language ~ '^[a-z]{2}$'),
  updated_at timestamptz not null default now(),
  primary key (org_id, user_id),
  foreign key (org_id, user_id) references public.org_members (org_id, user_id) on delete cascade
);

-- A sound of the workplace learned once by an admin, for every employee's device.
-- Only the fingerprint (a YAMNet embedding), never audio.
create table public.org_location_sounds (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  -- null = every location of the organization.
  location_id uuid,
  label text not null check (char_length(label) between 1 and 100),
  level public.alert_level not null default 'warning',
  model public.sound_model not null,
  fingerprint real[] not null check (array_ndims(fingerprint) = 1 and array_length(fingerprint, 1) = 1024),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (org_id, location_id) references public.org_locations (org_id, id) on delete cascade
);

create index org_location_sounds_org on public.org_location_sounds (org_id);

-- A critical alarm heard by an employee's device; the admins see who answered.
create table public.alarm_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  location_id uuid,
  -- The app's SoundKind name: "fireAlarm", "siren", ...
  kind text not null check (kind ~ '^[A-Za-z]{1,32}$'),
  started_by uuid default auth.uid() references auth.users (id) on delete set null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  check (ended_at is null or ended_at >= started_at),
  unique (org_id, id),
  foreign key (org_id, location_id) references public.org_locations (org_id, id) on delete set null (location_id)
);

create index alarm_events_open on public.alarm_events (org_id, started_at desc) where ended_at is null;

create table public.alarm_acks (
  event_id uuid not null,
  org_id uuid not null,
  user_id uuid not null,
  status public.ack_status not null,
  acked_at timestamptz not null default now(),
  primary key (event_id, user_id),
  foreign key (org_id, event_id) references public.alarm_events (org_id, id) on delete cascade,
  -- Leaving the organization removes the answers too.
  foreign key (org_id, user_id) references public.org_members (org_id, user_id) on delete cascade
);

-- Membership checks ------------------------------------------------------------------
-- security definer: policies on org_members use them without calling themselves.

create function public.is_org_member(target uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m where m.org_id = target and m.user_id = (select auth.uid())
  );
$$;

create function public.is_org_admin(target uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members m
    where m.org_id = target and m.user_id = (select auth.uid()) and m.role = 'admin'
  );
$$;

-- Guards ----------------------------------------------------------------------------

-- Admins manage role, department and location; each member manages only their own name.
create function public.guard_org_member_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if (new.role, new.department, new.location_id) is distinct from (old.role, old.department, old.location_id)
     and not public.is_org_admin(old.org_id) then
    raise exception 'only an admin can change role, department or location' using errcode = 'insufficient_privilege';
  end if;
  if new.display_name is distinct from old.display_name and old.user_id <> auth.uid() then
    raise exception 'only the member can change their name' using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger org_members_guard before update on public.org_members
  for each row execute function public.guard_org_member_update();

-- An organization always keeps an admin, except when it or the admin's account is deleted.
create function public.keep_an_admin() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'admin'
     and (tg_op = 'DELETE' or new.role <> 'admin')
     and exists (select 1 from public.organizations o where o.id = old.org_id)
     and exists (select 1 from auth.users u where u.id = old.user_id)
     and not exists (
       select 1 from public.org_members m
       where m.org_id = old.org_id and m.role = 'admin' and m.user_id <> old.user_id
     ) then
    raise exception 'an organization needs at least one admin';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger org_members_keep_admin before update or delete on public.org_members
  for each row execute function public.keep_an_admin();

create trigger organizations_touch before update on public.organizations
  for each row execute function public.touch_updated_at();
create trigger org_members_touch before update on public.org_members
  for each row execute function public.touch_updated_at();
create trigger member_needs_touch before update on public.member_needs
  for each row execute function public.touch_updated_at();

-- Actions ---------------------------------------------------------------------------

-- Creates the organization and makes the caller its first admin, in one step.
create function public.create_organization(org_name text) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  org uuid;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = 'insufficient_privilege';
  end if;
  insert into public.organizations (name) values (org_name) returning id into org;
  insert into public.org_members (org_id, user_id, role) values (org, auth.uid(), 'admin');
  return org;
end;
$$;

-- Joins the organization of an open invitation sent to the caller's email.
create function public.accept_invite(invite uuid) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  found public.org_invites;
begin
  select * into found from public.org_invites i
  where i.id = invite
    and i.accepted_at is null
    and i.expires_at > now()
    and i.email = lower(auth.jwt() ->> 'email')
  for update;
  if auth.uid() is null or found.id is null then
    raise exception 'invitation not found' using errcode = 'insufficient_privilege';
  end if;
  insert into public.org_members (org_id, user_id, role, department, location_id)
  values (found.org_id, auth.uid(), found.role, found.department, found.location_id)
  on conflict (org_id, user_id) do nothing;
  update public.org_invites set accepted_at = now() where id = found.id;
  return found.org_id;
end;
$$;

-- Opens an alarm, or returns the one already open for the same place in the last 10 minutes,
-- so every phone that hears the same fire alarm answers the same roll call.
create function public.report_alarm(target_org uuid, target_location uuid, alarm_kind text) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event uuid;
begin
  if not public.is_org_member(target_org) then
    raise exception 'not a member' using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtext(target_org::text || coalesce(target_location::text, '')));
  select e.id into event from public.alarm_events e
  where e.org_id = target_org
    and e.location_id is not distinct from target_location
    and e.ended_at is null
    and e.started_at > now() - interval '10 minutes'
  order by e.started_at desc
  limit 1;
  if event is null then
    insert into public.alarm_events (org_id, location_id, kind)
    values (target_org, target_location, alarm_kind)
    returning id into event;
  end if;
  return event;
end;
$$;

-- Row Level Security --------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.org_locations enable row level security;
alter table public.org_members enable row level security;
alter table public.org_invites enable row level security;
alter table public.member_needs enable row level security;
alter table public.org_location_sounds enable row level security;
alter table public.alarm_events enable row level security;
alter table public.alarm_acks enable row level security;

create policy "members read their organization" on public.organizations
  for select to authenticated using (public.is_org_member(id));
create policy "admins rename" on public.organizations
  for update to authenticated using (public.is_org_admin(id)) with check (public.is_org_admin(id));
create policy "admins delete" on public.organizations
  for delete to authenticated using (public.is_org_admin(id));

create policy "members read locations" on public.org_locations
  for select to authenticated using (public.is_org_member(org_id));
create policy "admins manage locations" on public.org_locations
  for all to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

-- Employees see only themselves: being listed can reveal a hearing impairment.
create policy "self or admins read members" on public.org_members
  for select to authenticated using (user_id = (select auth.uid()) or public.is_org_admin(org_id));
create policy "self or admins update members" on public.org_members
  for update to authenticated
  using (user_id = (select auth.uid()) or public.is_org_admin(org_id))
  with check (user_id = (select auth.uid()) or public.is_org_admin(org_id));
create policy "leave or be removed by an admin" on public.org_members
  for delete to authenticated using (user_id = (select auth.uid()) or public.is_org_admin(org_id));

create policy "admins and the invited person read invites" on public.org_invites
  for select to authenticated
  using (public.is_org_admin(org_id) or email = lower((select auth.jwt()) ->> 'email'));
create policy "admins invite" on public.org_invites
  for insert to authenticated with check (public.is_org_admin(org_id));
create policy "admins cancel invites" on public.org_invites
  for delete to authenticated using (public.is_org_admin(org_id));

create policy "self or admins read needs" on public.member_needs
  for select to authenticated using (user_id = (select auth.uid()) or public.is_org_admin(org_id));
create policy "only the employee writes needs" on public.member_needs
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_org_member(org_id));

create policy "members read location sounds" on public.org_location_sounds
  for select to authenticated using (public.is_org_member(org_id));
create policy "admins manage location sounds" on public.org_location_sounds
  for all to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

create policy "members read alarms" on public.alarm_events
  for select to authenticated using (public.is_org_member(org_id));
create policy "admins close alarms" on public.alarm_events
  for update to authenticated using (public.is_org_admin(org_id)) with check (public.is_org_admin(org_id));

create policy "self or admins read answers" on public.alarm_acks
  for select to authenticated using (user_id = (select auth.uid()) or public.is_org_admin(org_id));
create policy "members answer for themselves" on public.alarm_acks
  for insert to authenticated with check (user_id = (select auth.uid()) and public.is_org_member(org_id));
create policy "members change their answer" on public.alarm_acks
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_org_member(org_id));

-- Grants ------------------------------------------------------------------------------
-- Rows are created through the functions above where it matters (organizations,
-- memberships, alarms), so those tables get no direct insert.

revoke all on public.organizations, public.org_locations, public.org_members, public.org_invites,
  public.member_needs, public.org_location_sounds, public.alarm_events, public.alarm_acks from anon;

grant select, delete on public.organizations to authenticated;
grant update (name) on public.organizations to authenticated;
grant select, insert, update, delete on public.org_locations to authenticated;
grant select, delete on public.org_members to authenticated;
grant update (role, display_name, department, location_id) on public.org_members to authenticated;
grant select, insert, delete on public.org_invites to authenticated;
grant select, insert, update, delete on public.member_needs to authenticated;
grant select, insert, update, delete on public.org_location_sounds to authenticated;
grant select on public.alarm_events to authenticated;
grant update (ended_at) on public.alarm_events to authenticated;
grant select, insert on public.alarm_acks to authenticated;
grant update (status, acked_at) on public.alarm_acks to authenticated;

revoke execute on function public.is_org_member(uuid), public.is_org_admin(uuid),
  public.create_organization(text), public.accept_invite(uuid), public.report_alarm(uuid, uuid, text)
  from public, anon;
grant execute on function public.is_org_member(uuid), public.is_org_admin(uuid),
  public.create_organization(text), public.accept_invite(uuid), public.report_alarm(uuid, uuid, text)
  to authenticated;
