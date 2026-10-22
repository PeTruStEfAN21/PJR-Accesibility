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

grant usage on schema auth to anon, authenticated;
grant usage on schema public to anon, authenticated;
