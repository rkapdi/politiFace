-- Minimal Supabase shim for plain-Postgres migration testing.
-- Mimics: auth schema, auth.users, auth.uid(), client roles, default grants.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema if not exists auth;
create table if not exists auth.users (
  id    uuid primary key,
  email text
);

-- Test stand-in for Supabase's JWT-based auth.uid().
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('app.test_uid', true), '')::uuid;
$$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Test stand-in for Supabase's auth.jwt(): the claims of the current JWT.
-- Tests set app.test_jwt to a JSON object (for example '{"is_anonymous": true}').
create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('app.test_jwt', true), ''), '{}')::jsonb;
$$;
grant execute on function auth.jwt() to anon, authenticated, service_role;
