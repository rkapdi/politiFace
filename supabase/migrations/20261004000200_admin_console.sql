-- Admin console phase 2a (spec 2026-10-04): an audit log, a problem log
-- the web and iOS clients write to, and admin-only read and write RPCs.
-- Admins are exactly app.admins (the two founders); both see all data.

-- ── audit log ──────────────────────────────────────────────────────────────
create table app.admin_audit (
  id             bigserial primary key,
  actor          uuid references public.profiles (id) on delete set null,
  action         text not null check (length(action) between 3 and 40),
  target_user    uuid,
  target_cohort  uuid,
  target_session uuid,
  details        jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);
create index admin_audit_created_idx on app.admin_audit (created_at desc);
create index admin_audit_target_user_idx on app.admin_audit (target_user, created_at desc);
-- Written and read only through admin RPCs.
alter table app.admin_audit enable row level security;

create function app.audit(
  p_action text,
  p_user uuid default null,
  p_cohort uuid default null,
  p_session uuid default null,
  p_details jsonb default '{}'::jsonb
) returns void
language sql security definer set search_path = public, app, pg_temp as $$
  insert into app.admin_audit (actor, action, target_user, target_cohort,
                               target_session, details)
  values (auth.uid(), p_action, p_user, p_cohort, p_session,
          coalesce(p_details, '{}'::jsonb));
$$;

-- ── problem log ────────────────────────────────────────────────────────────
-- Typed email only on sign-in failures (no account exists yet); 90 days.
create table app.ops_events (
  id          bigserial primary key,
  user_id     uuid references auth.users (id) on delete cascade,
  email       text check (email is null or length(email) <= 254),
  kind        text not null check (kind in ('signin_send_failed',
                'signin_verify_failed', 'join_refused', 'client_error', 'app_seen')),
  code        text check (code is null or length(code) <= 80),
  detail      jsonb not null default '{}'::jsonb,
  client      text not null check (client in ('web', 'ios')),
  app_version text check (app_version is null or length(app_version) <= 40),
  created_at  timestamptz not null default now()
);
create index ops_events_created_idx on app.ops_events (created_at desc);
create index ops_events_user_idx on app.ops_events (user_id, created_at desc);
create index ops_events_email_idx on app.ops_events (email, created_at desc)
  where email is not null;
alter table app.ops_events enable row level security;

create function public.log_ops_event(
  p_kind text,
  p_client text,
  p_code text default null,
  p_detail jsonb default null,
  p_app_version text default null,
  p_email text default null
) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_email text;
  v_recent int;
begin
  if p_kind not in ('signin_send_failed', 'signin_verify_failed',
                    'join_refused', 'client_error', 'app_seen')
     or p_client not in ('web', 'ios') then
    raise exception 'invalid ops event';
  end if;
  if p_detail is not null and pg_column_size(p_detail) > 2048 then
    raise exception 'ops detail too large';
  end if;
  v_email := case when p_kind like 'signin_%'
                  then nullif(lower(trim(coalesce(p_email, ''))), '') end;
  if length(v_email) > 254 then v_email := null; end if;
  -- Unattributable rows are dropped, never stored.
  if v_user is null and v_email is null then return; end if;

  select count(*) into v_recent from app.ops_events
   where kind = p_kind and created_at > now() - interval '1 minute'
     and ((v_user is not null and user_id = v_user)
          or (v_user is null and email = v_email));
  if v_recent >= 30 then return; end if;

  if p_kind = 'app_seen' then
    if v_user is null then return; end if;
    if exists (select 1 from app.ops_events
                where kind = 'app_seen' and user_id = v_user
                  and client = p_client
                  and created_at >= date_trunc('day', now())) then
      return;
    end if;
  end if;

  insert into app.ops_events (user_id, email, kind, code, detail, client, app_version)
  values (v_user, v_email, p_kind, left(p_code, 80), coalesce(p_detail, '{}'::jsonb),
          p_client, left(p_app_version, 40));
end;
$$;
revoke all on function public.log_ops_event(text, text, text, jsonb, text, text) from public;
grant execute on function public.log_ops_event(text, text, text, jsonb, text, text)
  to anon, authenticated;

create function app.purge_ops_events() returns void
language sql security definer set search_path = public, app, pg_temp as $$
  delete from app.ops_events where created_at < now() - interval '90 days';
$$;

do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'ops purge cron: pg_cron not installed; skipping';
    return;
  end if;
  if exists (select 1 from cron.job where jobname = 'purge-ops-events') then
    perform cron.unschedule('purge-ops-events');
  end if;
  perform cron.schedule('purge-ops-events', '17 4 * * *',
    'select app.purge_ops_events()');
end $$;
