-- The few Supabase pieces the migrations rely on, so they can run on a plain
-- PostgreSQL in tests. On Supabase itself these already exist.

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end
$$;

create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);

-- Supabase reads the caller from the JWT; tests set the same setting by hand.
create function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

-- The whole token as JSON (e.g. the email an invitation is matched against).
create function auth.jwt() returns jsonb
language sql stable
as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;

grant usage on schema auth to anon, authenticated;
grant usage on schema public to anon, authenticated;

-- Supabase gives anon and authenticated every privilege on whatever is created in
-- public; a migration that wants less must revoke it. Tests start from the same place.
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
