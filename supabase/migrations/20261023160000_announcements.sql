-- Echo: company announcements (docs/superpowers/specs/2026-10-23-anunturi-design.md).
-- The admin writes to the whole team ("Mâine plecăm cu 2 ore mai devreme, se face dezinsecție"); every
-- employee reads it, whether they read or hear what is said, and marks it seen. The admin sees only
-- how many saw it, never who.
--
-- GDPR: the text is the company's; about people we keep only "saw announcement X at Y". An
-- announcement shows for 1 to 90 days and is deleted at the company's next post once expired; seen
-- marks go with it, and with the person's account.

alter type public.activity_event add value if not exists 'announcement_posted';
alter type public.activity_event add value if not exists 'announcement_deleted';

-- Tables ----------------------------------------------------------------------------------

create table public.org_announcements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  author_id uuid default auth.uid() references auth.users (id) on delete set null,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  important boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at and expires_at <= created_at + interval '90 days')
);

create index org_announcements_org on public.org_announcements (org_id, created_at desc);

create table public.org_announcement_reads (
  announcement_id uuid not null references public.org_announcements (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

create index org_announcement_reads_user on public.org_announcement_reads (user_id);

alter table public.org_announcements enable row level security;
alter table public.org_announcement_reads enable row level security;

create policy "members read their company's announcements while they show" on public.org_announcements
  for select to authenticated using (public.is_org_member(org_id) and expires_at > now());

create policy "each person marks what they saw" on public.org_announcement_reads
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.org_announcements a where a.id = announcement_id)
  );
create policy "each person sees their own marks" on public.org_announcement_reads
  for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.org_announcements, public.org_announcement_reads from public, anon, authenticated;
grant select on public.org_announcements to authenticated;
-- Only the announcement: user_id is always the caller (its default), seen_at the server's time.
grant select, insert (announcement_id) on public.org_announcement_reads to authenticated;

-- Writing (admins) -----------------------------------------------------------------------------

create function public.post_announcement(target_org uuid, title text, body text, important boolean, days integer)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  posted uuid;
begin
  if auth.uid() is null or not public.is_org_admin(target_org) then
    raise exception 'only an admin of the company can post' using errcode = 'insufficient_privilege';
  end if;
  if days is null or days not between 1 and 90 then
    raise exception 'an announcement shows for 1 to 90 days' using errcode = 'invalid_parameter_value';
  end if;
  delete from public.org_announcements a where a.org_id = target_org and a.expires_at <= now();
  insert into public.org_announcements (org_id, author_id, title, body, important, expires_at)
  values (target_org, auth.uid(), btrim(title), btrim(body), coalesce(important, false), now() + make_interval(days => days))
  returning id into posted;
  perform public.log_activity('announcement_posted', auth.uid(), array[target_org], posted::text,
                              p_title => btrim(title));
  return posted;
end;
$$;

create function public.delete_announcement(announcement uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  found public.org_announcements;
begin
  select * into found from public.org_announcements a where a.id = announcement;
  if auth.uid() is null or found.id is null or not public.is_org_admin(found.org_id) then
    raise exception 'only an admin of the company can delete it' using errcode = 'insufficient_privilege';
  end if;
  delete from public.org_announcements a where a.id = announcement;
  perform public.log_activity('announcement_deleted', auth.uid(), array[found.org_id], found.id::text,
                              p_title => found.title);
end;
$$;

-- How many saw each announcement, out of the company's members other than its author (admins only).
create function public.announcement_seen(target_org uuid)
returns table (announcement_id uuid, seen integer, audience integer)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id,
         (select count(*)::integer from public.org_announcement_reads r
            join public.org_members m on m.org_id = a.org_id and m.user_id = r.user_id
           where r.announcement_id = a.id and r.user_id is distinct from a.author_id),
         (select count(*)::integer from public.org_members m
           where m.org_id = a.org_id and m.user_id is distinct from a.author_id)
  from public.org_announcements a
  where a.org_id = target_org and a.expires_at > now() and public.is_org_admin(target_org)
  order by a.created_at desc;
$$;

revoke execute on function public.post_announcement(uuid, text, text, boolean, integer),
  public.delete_announcement(uuid), public.announcement_seen(uuid)
  from public, anon;
grant execute on function public.post_announcement(uuid, text, text, boolean, integer),
  public.delete_announcement(uuid), public.announcement_seen(uuid)
  to authenticated;
