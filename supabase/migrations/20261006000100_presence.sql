-- Presence (admin console): who has the app or web console open right now.
-- Clients send a heartbeat when opened and every 60 seconds while on
-- screen. One row per person per client, overwritten each time: no
-- history, nothing but the last-seen time and app version. Admin-only reads.

create table app.presence (
  user_id      uuid not null references auth.users (id) on delete cascade,
  client       text not null check (client in ('web', 'ios')),
  is_guest     boolean not null default false,
  app_version  text check (app_version is null or length(app_version) <= 40),
  last_seen_at timestamptz not null default now(),
  primary key (user_id, client)
);
create index presence_last_seen_idx on app.presence (last_seen_at desc);
alter table app.presence enable row level security;

-- Signed-in callers only (anonymous guest sessions included, flagged as
-- guests). Writes at most once per 20 seconds per person and client.
create function public.heartbeat(p_client text, p_app_version text default null)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then return; end if;
  if p_client is null or p_client not in ('web', 'ios') then
    raise exception 'invalid client';
  end if;
  insert into app.presence (user_id, client, is_guest, app_version, last_seen_at)
  values (v_user, p_client,
          coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false),
          left(p_app_version, 40), now())
  on conflict (user_id, client) do update
     set last_seen_at = now(),
         app_version = excluded.app_version,
         is_guest = excluded.is_guest
   where app.presence.last_seen_at < now() - interval '20 seconds';
end;
$$;
revoke all on function public.heartbeat(text, text) from public, anon;
grant execute on function public.heartbeat(text, text) to authenticated;

-- Online = seen in the last 2 minutes.
create function public.admin_online() returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return (
    with online as (
      select pr.user_id, pr.client, pr.is_guest, pr.app_version, pr.last_seen_at
        from app.presence pr
       where pr.last_seen_at > now() - interval '2 minutes'
    )
    select jsonb_build_object(
      'total', (select count(distinct user_id) from online),
      'ios', (select count(*) from online where client = 'ios'),
      'web', (select count(*) from online where client = 'web'),
      'guests', (select count(distinct user_id) from online where is_guest),
      'people', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'user_id', o.user_id,
                 'name', coalesce(
                   (select min(m.roster_name) from public.cohort_members m
                     where m.user_id = o.user_id and m.roster_name is not null),
                   p.handle, 'unknown'),
                 'clients', o.clients,
                 'app_version', o.app_version,
                 'last_seen_at', o.last_seen_at) order by o.last_seen_at desc)
          from (select user_id,
                       array_agg(client order by client) clients,
                       max(app_version) filter (where client = 'ios') app_version,
                       max(last_seen_at) last_seen_at
                  from online where not is_guest
                 group by user_id) o
          left join public.profiles p on p.id = o.user_id), '[]'::jsonb)
    )
  );
end;
$$;
revoke all on function public.admin_online() from public, anon;
grant execute on function public.admin_online() to authenticated;

create function public.admin_last_seen(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return coalesce((
    select jsonb_object_agg(pr.client, pr.last_seen_at)
      from app.presence pr where pr.user_id = p_user), '{}'::jsonb);
end;
$$;
revoke all on function public.admin_last_seen(uuid) from public, anon;
grant execute on function public.admin_last_seen(uuid) to authenticated;

-- The daily purge also drops presence rows not refreshed in 90 days.
create or replace function app.purge_ops_events() returns void
language sql security definer set search_path = public, app, pg_temp as $$
  delete from app.ops_events where created_at < now() - interval '90 days';
  delete from app.presence where last_seen_at < now() - interval '90 days';
$$;
