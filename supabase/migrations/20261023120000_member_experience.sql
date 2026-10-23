-- Echo: how each member uses Echo, which picks the phone's interface.
--   standard  hears the room; the app shows the colleague tools (alarms, clarity coach).
--   visual    reads what is said; the app shows captions, visible sounds, visual alerts.
-- Admin is not a third kind: the admin interface sits on top of the member's own kind
-- (role says what they manage, experience says how they take part).
--
-- GDPR: "visual" reveals a hearing impairment, so it is health data (art. 9). It is kept as
-- a need ("receives everything visually"), never as a diagnosis, and only for the safety of
-- the employee and the adaptation of their workplace (art. 9(2)(b)). An admin may set it on
-- the invitation; the invited person sees it before accepting, and afterwards changes it
-- whenever they want (art. 16). experience_confirmed_at stays empty until the member
-- chooses or confirms it themselves, so the app asks them. Employees still see only
-- themselves among members. Every change made by someone else goes into the activity log,
-- without the value; leaving the company removes those rows, the type goes with the member row.

alter type public.activity_event add value if not exists 'member_experience_changed';

create type public.member_experience as enum ('standard', 'visual');

alter table public.org_members
  add column experience public.member_experience not null default 'standard',
  add column experience_confirmed_at timestamptz;

alter table public.org_invites
  add column experience public.member_experience not null default 'standard';

-- Who may change it, and when it counts as the member's own choice ----------------------

-- Both the member and the company's admins may change it (RLS lets only them update the
-- row). Only the member's own change or confirmation counts as confirmed, at the server's time.
create function public.guard_member_experience() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if old.user_id = auth.uid() then
    if new.experience is distinct from old.experience
       or new.experience_confirmed_at is distinct from old.experience_confirmed_at then
      new.experience_confirmed_at := now();
    end if;
  elsif new.experience_confirmed_at is distinct from old.experience_confirmed_at then
    raise exception 'only the member can confirm how they use Echo' using errcode = 'insufficient_privilege';
  elsif new.experience is distinct from old.experience then
    new.experience_confirmed_at := null;
  end if;
  return new;
end;
$$;

create trigger org_members_experience before update on public.org_members
  for each row execute function public.guard_member_experience();

-- The log row says who changed whose type and when; ref is the company, so the row can go
-- when the member leaves it.
create function public.log_member_experience() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.experience is distinct from old.experience
     and auth.uid() is not null and auth.uid() <> new.user_id then
    perform public.log_activity('member_experience_changed', auth.uid(), array[new.org_id], new.org_id::text,
                                p_subject => new.user_id);
  end if;
  return null;
end;
$$;

create trigger org_members_experience_log after update on public.org_members
  for each row execute function public.log_member_experience();

create function public.forget_member_experience() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_log a
  where a.event = 'member_experience_changed'
    and a.subject_user_id = old.user_id
    and a.ref = old.org_id::text;
  return null;
end;
$$;

create trigger org_members_forget_experience after delete on public.org_members
  for each row execute function public.forget_member_experience();

-- Invitations carry it ------------------------------------------------------------------

create or replace function public.accept_invite(invite uuid) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  found public.org_invites;
  joined integer;
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
  insert into public.org_members (org_id, user_id, role, email, department, location_id, experience)
  values (found.org_id, auth.uid(), found.role, found.email, found.department, found.location_id, found.experience)
  on conflict (org_id, user_id) do nothing;
  get diagnostics joined = row_count;
  -- The admin who invited chose a type for them: written down like any later change.
  if joined > 0 and found.experience <> 'standard' then
    perform public.log_activity('member_experience_changed', found.invited_by, array[found.org_id],
                                found.org_id::text, p_subject => auth.uid());
  end if;
  update public.org_invites set accepted_at = now() where id = found.id;
  return found.org_id;
end;
$$;

-- The invited person sees the type chosen for them before accepting.
drop function public.my_invites();
create function public.my_invites()
returns table (id uuid, org_id uuid, org_name text, role public.org_role, expires_at timestamptz,
               experience public.member_experience)
language sql
stable
security definer
set search_path = ''
as $$
  select i.id, i.org_id, o.name, i.role, i.expires_at, i.experience
  from public.org_invites i
  join public.organizations o on o.id = i.org_id
  where i.email = lower((select auth.jwt()) ->> 'email')
    and i.accepted_at is null
    and i.expires_at > now()
  order by i.created_at desc;
$$;

-- Privileges ------------------------------------------------------------------------------

grant update (experience, experience_confirmed_at) on public.org_members to authenticated;
grant insert (experience) on public.org_invites to authenticated;

revoke execute on function public.guard_member_experience(), public.log_member_experience(),
  public.forget_member_experience(), public.my_invites()
  from public, anon, authenticated;
grant execute on function public.my_invites() to authenticated;
