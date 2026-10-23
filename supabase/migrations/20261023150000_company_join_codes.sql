-- Echo: joining a company with its code (docs/specs/2026-10-23-login-cod-companie-design.md).
-- The admin makes a code and hands it to the employees; an employee signs in with an email code,
-- types the company code, their name and how they use Echo, and is in the company.
--
-- Security: only a fingerprint (SHA-256) of the code is kept, a code lasts 7 days and a company
-- has one at a time; an account gets 5 wrong codes an hour. Nobody reads the two tables directly.
-- GDPR: the employee is told, before joining, that the admins see their name, email and how they
-- use Echo. Attempts keep only the account and the time, for an hour. Deleting the account takes
-- the attempts and the join out of the history.

alter type public.activity_event add value if not exists 'member_joined';
alter type public.activity_event add value if not exists 'member_left';
alter type public.activity_event add value if not exists 'member_removed';

-- Tables --------------------------------------------------------------------------------

create table public.org_join_codes (
  org_id uuid primary key references public.organizations (id) on delete cascade,
  code_hash bytea not null unique,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);

create table public.org_join_attempts (
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);

create index org_join_attempts_user on public.org_join_attempts (user_id, at);

alter table public.org_join_codes enable row level security;
alter table public.org_join_attempts enable row level security;
revoke all on public.org_join_codes, public.org_join_attempts from public, anon, authenticated;

-- Codes -----------------------------------------------------------------------------------

-- People type a code as they read it: spaces, dashes and small letters do not matter.
create function public.join_code_fingerprint(code text) returns bytea
language sql
immutable
set search_path = ''
as $$
  select sha256(convert_to(upper(regexp_replace(coalesce(code, ''), '[^A-Za-z0-9]', '', 'g')), 'UTF8'));
$$;

-- A new code for the company, shown once; the previous one stops working.
-- 8 characters without 0/O, 1/I/L, from a strong random source (gen_random_uuid).
create function public.new_join_code(target_org uuid) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  raw bytea := uuid_send(gen_random_uuid());
  plain text := '';
  i integer;
begin
  if auth.uid() is null or not public.is_org_admin(target_org) then
    raise exception 'only an admin of the company can make its code' using errcode = 'insufficient_privilege';
  end if;
  -- Bytes 6 and 8 carry the uuid's version and variant, so they are skipped.
  foreach i in array array[0, 1, 2, 3, 4, 5, 9, 10] loop
    plain := plain || substr(alphabet, get_byte(raw, i) % 31 + 1, 1);
  end loop;
  insert into public.org_join_codes (org_id, code_hash, created_by)
  values (target_org, public.join_code_fingerprint(plain), auth.uid())
  on conflict (org_id) do update
    set code_hash = excluded.code_hash, created_by = excluded.created_by,
        created_at = now(), expires_at = now() + interval '7 days';
  return left(plain, 4) || '-' || right(plain, 4);
end;
$$;

-- Whether the company has a code that still works, and until when (never the code itself).
create function public.join_code_info(target_org uuid) returns table (expires_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.expires_at from public.org_join_codes c
  where c.org_id = target_org and c.expires_at > now() and public.is_org_admin(target_org);
$$;

create function public.revoke_join_code(target_org uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_org_admin(target_org) then
    raise exception 'only an admin of the company can cancel its code' using errcode = 'insufficient_privilege';
  end if;
  delete from public.org_join_codes c where c.org_id = target_org;
end;
$$;

-- Joins the company of the code as an employee with the given name and way of using Echo
-- (their own choice, so it counts as confirmed). Returns the company, or null for a wrong or
-- expired code; after 5 wrong codes in an hour it refuses (EJ002). Someone already in the
-- company stays as they are.
create function public.join_with_code(code text, member_name text, member_experience public.member_experience)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  clean text := btrim(member_name);
  found uuid;
  joined uuid;
begin
  if me is null then
    raise exception 'not signed in' using errcode = 'insufficient_privilege';
  end if;
  if clean is null or char_length(clean) not between 1 and 100 then
    raise exception 'a name of 1 to 100 characters is needed' using errcode = 'check_violation';
  end if;
  delete from public.org_join_attempts a where a.user_id = me and a.at < now() - interval '1 hour';
  if (select count(*) from public.org_join_attempts a where a.user_id = me) >= 5 then
    raise exception 'too many wrong codes, try again later' using errcode = 'EJ002';
  end if;
  select c.org_id into found from public.org_join_codes c
  where c.code_hash = public.join_code_fingerprint(code) and c.expires_at > now();
  if found is null then
    insert into public.org_join_attempts (user_id) values (me);
    return null;
  end if;
  insert into public.org_members (org_id, user_id, role, email, display_name, experience, experience_confirmed_at)
  values (found, me, 'employee', lower(auth.jwt() ->> 'email'), clean, member_experience, now())
  on conflict (org_id, user_id) do nothing
  returning user_id into joined;
  if joined is not null then
    perform public.log_activity('member_joined', me, array[found], found::text);
  end if;
  return found;
end;
$$;

-- History: joining, leaving, being removed -------------------------------------------------

-- Joining with a code is logged by join_with_code (invitations keep their own flow).
-- Not when the company or the account is being deleted: nothing is left to tell.
create function public.log_member_gone() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or not exists (select 1 from public.organizations o where o.id = old.org_id)
     or not exists (select 1 from auth.users u where u.id = old.user_id) then
    return null;
  end if;
  if old.user_id = auth.uid() then
    perform public.log_activity('member_left', old.user_id, array[old.org_id], old.org_id::text);
  else
    perform public.log_activity('member_removed', auth.uid(), array[old.org_id], old.org_id::text,
                                p_subject => old.user_id);
  end if;
  return null;
end;
$$;

create trigger org_members_log_gone after delete on public.org_members
  for each row execute function public.log_member_gone();

-- A deleted account leaves no trace of joining or leaving, and is no longer named as removed.
-- The name sorts before on_auth_user_deleted_forget_activity, which clears actor_id: this runs first.
create function public.forget_membership_activity() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_log a
  where a.actor_id = old.id and a.event in ('member_joined', 'member_left');
  update public.activity_log a set subject_user_id = null, subject_email = null
  where a.subject_user_id = old.id and a.event = 'member_removed';
  return null;
end;
$$;

create trigger on_auth_user_deleted_clear_membership after delete on auth.users
  for each row execute function public.forget_membership_activity();

-- Who may call what -----------------------------------------------------------------------

revoke execute on function public.join_code_fingerprint(text), public.new_join_code(uuid),
  public.join_code_info(uuid), public.revoke_join_code(uuid),
  public.join_with_code(text, text, public.member_experience),
  public.log_member_gone(), public.forget_membership_activity()
  from public, anon, authenticated;
grant execute on function public.new_join_code(uuid), public.join_code_info(uuid), public.revoke_join_code(uuid),
  public.join_with_code(text, text, public.member_experience)
  to authenticated;
