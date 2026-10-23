-- Echo: what the Supabase security advisor found on the hosted project.
-- 1. The activity log tables had no Row Level Security. Nobody had privileges on them, so
--    nothing leaked; RLS without policies now refuses access even if a grant is ever added.
--    The functions that write and read the log run as the table owner, which RLS skips.
-- 2. Trigger functions could be called through /rest/v1/rpc (Postgres checks EXECUTE only
--    when a trigger is created, never when it fires), and signed-out requests could call
--    the helpers. Signed-out requests now call nothing; signed-in ones keep the functions
--    the app and the policies use.

alter table public.activity_log enable row level security;
alter table public.activity_log_orgs enable row level security;

do $$
declare
  f regprocedure;
begin
  for f in
    select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format('revoke execute on function %s from public, anon', f);
  end loop;
  for f in
    select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke execute on function %s from authenticated', f);
  end loop;
end
$$;
