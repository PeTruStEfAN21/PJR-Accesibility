-- Echo: accounts and the meetings each participant saves to review later.
-- Every row belongs to one user and Row Level Security keeps it private to them,
-- whoever asks: the app (anon key + user token) or our server (same user token).
-- Audio and video are never stored: only the final caption text.

-- Profiles ------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 100),
  -- Accessibility settings synced between the user's devices (same keys as on the phone).
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Meetings ------------------------------------------------------------------

create type public.speaker as enum ('coordinator', 'public');

create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text check (char_length(title) <= 200),
  -- Speech locale of the meeting, as on the phone: "ro-RO", "en-US".
  lang text not null check (lang ~ '^[a-z]{2}([-_][A-Za-z]{2})?$'),
  session_code text check (char_length(session_code) <= 16),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ended_at is null or ended_at >= started_at)
);

create index meetings_owner_started on public.meetings (owner_id, started_at desc);

-- One row per final caption. seq numbers the lines from 1, the same numbers
-- the AI cites as [#seq]. caption_id makes saving idempotent: the phone can
-- resend a batch after a dropped connection without duplicating lines.
create table public.meeting_lines (
  meeting_id uuid not null references public.meetings (id) on delete cascade,
  seq integer not null check (seq >= 1),
  caption_id text not null check (char_length(caption_id) between 1 and 64),
  speaker public.speaker not null,
  text text not null check (char_length(text) between 1 and 2000),
  spoken_at timestamptz not null,
  -- "simple": no stemming, so one index serves Romanian and English alike.
  search tsvector generated always as (to_tsvector('simple', text)) stored,
  primary key (meeting_id, seq),
  unique (meeting_id, caption_id)
);

create index meeting_lines_search on public.meeting_lines using gin (search);

create table public.summaries (
  meeting_id uuid primary key references public.meetings (id) on delete cascade,
  summary text not null check (char_length(summary) <= 20000),
  -- [{"text": "...", "owner": "..." | null}], as returned by /api/ai/summary.
  tasks jsonb not null default '[]'::jsonb check (jsonb_typeof(tasks) = 'array'),
  lang text not null check (lang ~ '^[a-z]{2}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Housekeeping ----------------------------------------------------------------

create function public.touch_updated_at() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger meetings_touch before update on public.meetings
  for each row execute function public.touch_updated_at();
create trigger summaries_touch before update on public.summaries
  for each row execute function public.touch_updated_at();

-- Every new account gets a profile, whatever the sign-in method.
create function public.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row Level Security --------------------------------------------------------------
-- (select auth.uid()) instead of auth.uid(): evaluated once per query, not per row.

alter table public.profiles enable row level security;
alter table public.meetings enable row level security;
alter table public.meeting_lines enable row level security;
alter table public.summaries enable row level security;

create policy "own profile: read" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "own profile: update" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "own meetings" on public.meetings
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create function public.owns_meeting(target uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.meetings m where m.id = target and m.owner_id = (select auth.uid()));
$$;

create policy "lines of own meetings" on public.meeting_lines
  for all to authenticated
  using (public.owns_meeting(meeting_id))
  with check (public.owns_meeting(meeting_id));

create policy "summaries of own meetings" on public.summaries
  for all to authenticated
  using (public.owns_meeting(meeting_id))
  with check (public.owns_meeting(meeting_id));

-- Nothing is readable without signing in.
revoke all on public.profiles, public.meetings, public.meeting_lines, public.summaries from anon;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.meetings, public.meeting_lines, public.summaries to authenticated;

-- Search ----------------------------------------------------------------------------
-- The user's meetings whose title or lines match, newest first, with the first
-- matching line as a preview. Runs as the caller, so RLS still applies.

create function public.search_meetings(query text)
returns table (meeting_id uuid, title text, started_at timestamptz, seq integer, snippet text)
language sql
stable
set search_path = ''
as $$
  with q as (select websearch_to_tsquery('simple', query) as tsq)
  select distinct on (m.started_at, m.id)
    m.id, m.title, m.started_at, l.seq, l.text
  from public.meetings m
  cross join q
  left join public.meeting_lines l on l.meeting_id = m.id and l.search @@ q.tsq
  where l.seq is not null or m.title ilike '%' || query || '%'
  order by m.started_at desc, m.id, l.seq
  limit 50;
$$;

revoke execute on function public.search_meetings(text) from public, anon;
grant execute on function public.search_meetings(text) to authenticated;

-- Account deletion -----------------------------------------------------------------
-- The phone cannot delete its own auth user, so this function does it for the
-- caller only. Cascades remove the profile, meetings, lines and summaries.

create function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
