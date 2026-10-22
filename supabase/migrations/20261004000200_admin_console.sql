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
  -- True for both unauthenticated callers and anonymous-auth sessions
  -- (Supabase anonymous sign-in): both share the global flood bucket below.
  anon        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index ops_events_created_idx on app.ops_events (created_at desc);
create index ops_events_user_idx on app.ops_events (user_id, created_at desc);
create index ops_events_email_idx on app.ops_events (email, created_at desc)
  where email is not null;
create index ops_events_anon_created_idx on app.ops_events (created_at) where anon;
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
  -- Anonymous-auth sessions (Supabase anonymous sign-in) are treated the
  -- same as a fully signed-out caller for flood-control purposes: both
  -- share one identity-less bucket, not 1-per-session buckets.
  v_anon boolean := v_user is null
    or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
  v_email text;
  v_recent int;
  v_total int;
begin
  if p_kind is null or p_client is null
     or p_kind not in ('signin_send_failed', 'signin_verify_failed',
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

  -- Total ceiling across all writers, authenticated or not: a hard floor
  -- under the whole table regardless of who is calling.
  select count(*) into v_total from app.ops_events
   where created_at > now() - interval '1 minute';
  if v_total >= 600 then return; end if;

  -- Global anonymous flood guard: caps unauthenticated AND anonymous-auth
  -- writes together, so neither a spray of distinct emails nor a spray of
  -- anonymous-auth sessions can bypass the per-kind cap below.
  if v_anon then
    if (select count(*) from app.ops_events
         where anon and created_at > now() - interval '1 minute') >= 120 then
      return;
    end if;
  end if;

  select count(*) into v_recent from app.ops_events
   where kind = p_kind and created_at > now() - interval '1 minute'
     and ((v_user is not null and user_id = v_user)
          or (v_user is null and email = v_email));
  if v_recent >= 10 then return; end if;

  if p_kind = 'app_seen' then
    if v_user is null then return; end if;
    if exists (select 1 from app.ops_events
                where kind = 'app_seen' and user_id = v_user
                  and client = p_client
                  and app_version is not distinct from left(p_app_version, 40)
                  and created_at >= date_trunc('day', now())) then
      return;
    end if;
  end if;

  insert into app.ops_events (user_id, email, kind, code, detail, client, app_version, anon)
  values (v_user, v_email, p_kind, left(p_code, 80), coalesce(p_detail, '{}'::jsonb),
          p_client, left(p_app_version, 40), v_anon);
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

-- ── home ───────────────────────────────────────────────────────────────────
create function public.admin_home() returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return jsonb_build_object(
    'totals', jsonb_build_object(
      'people', (select count(*) from public.profiles where not is_guest),
      'students', (select count(distinct user_id) from public.cohort_members
                    where role = 'student'),
      'faculty', (select count(*) from app.verified_faculty),
      'classes', (select count(*) from public.cohorts),
      'answered_live_7d', (select count(distinct user_id) from public.live_answers
                            where created_at > now() - interval '7 days')),
    'live_now', coalesce((
      select jsonb_agg(jsonb_build_object(
               'session_id', s.id, 'title', s.title, 'cohort_id', c.id,
               'class', c.name, 'professor', p.handle, 'status', s.status,
               'index', s.current_index,
               'total', jsonb_array_length(s.question_ids),
               'participants', (select count(*) from public.live_participants lp
                                 where lp.session_id = s.id),
               'created_at', s.created_at) order by s.created_at desc)
        from public.live_sessions s
        join public.cohorts c on c.id = s.cohort_id
        left join public.profiles p on p.id = s.created_by
       where s.status <> 'ended'), '[]'::jsonb),
    'pending_requests', (select count(*) from public.faculty_access_requests
                          where status = 'pending'),
    'funnel', coalesce((
      select jsonb_agg(f order by f ->> 'name') from (
        select jsonb_build_object(
          'cohort_id', c.id, 'name', c.name, 'term', c.term,
          'members', (select count(*) from public.cohort_members m
                       where m.cohort_id = c.id),
          'students', (select count(*) from public.cohort_members m
                        where m.cohort_id = c.id and m.role = 'student'),
          'answered_live', (select count(distinct a.user_id)
                              from public.live_answers a
                              join public.live_sessions s on s.id = a.session_id
                              join public.cohort_members m
                                on m.cohort_id = c.id and m.user_id = a.user_id
                               and m.role = 'student'
                             where s.cohort_id = c.id),
          'practiced_7d', (select count(distinct e.user_id)
                             from public.events e
                             join public.cohort_members m
                               on m.cohort_id = c.id and m.user_id = e.user_id
                              and m.role = 'student'
                            where e.cohort_id = c.id
                              and e.server_ts > now() - interval '7 days')) f
          from public.cohorts c) x), '[]'::jsonb),
    'attention', coalesce((
      select jsonb_agg(a) from (
        select jsonb_build_object('kind', 'requests', 'severity', 'warn',
                 'title', count(*) || ' instructor request(s) pending') a
          from public.faculty_access_requests where status = 'pending'
        having count(*) > 0
        union all
        select jsonb_build_object('kind', 'stalled', 'severity', 'warn',
                 'cohort_id', cs.id,
                 'title', cs.name || ': ' || cs.act || ' of ' || cs.st
                          || ' students active this week')
          from (select c.id, c.name,
                       (select count(*) from public.cohort_members m
                         where m.cohort_id = c.id and m.role = 'student') st,
                       (select count(distinct e.user_id) from public.events e
                         join public.cohort_members m
                           on m.cohort_id = c.id and m.user_id = e.user_id
                          and m.role = 'student'
                         where e.cohort_id = c.id
                           and e.server_ts > now() - interval '7 days') act
                  from public.cohorts c) cs
         where cs.st >= 5 and cs.act * 2 < cs.st
        union all
        select jsonb_build_object('kind', 'duplicates', 'severity', 'warn',
                 'cohort_id', m.cohort_id,
                 'title', (select name from public.cohorts where id = m.cohort_id)
                          || ': "' || min(m.roster_name) || '" is listed '
                          || count(*) || ' times')
          from public.cohort_members m
         where m.role = 'student' and m.roster_name is not null
         group by m.cohort_id, lower(m.roster_name)
        having count(*) > 1
        union all
        select jsonb_build_object('kind', 'signin_failures', 'severity', 'fail',
                 'title', count(*) || ' sign-in failures in the last hour')
          from app.ops_events
         where kind like 'signin_%' and created_at > now() - interval '1 hour'
        having count(*) > 10
      ) x), '[]'::jsonb),
    'health', (select jsonb_build_object('run_at', r.run_at, 'ok', r.ok,
                                          'failures', r.failures)
                 from app.canary_runs r order by r.id desc limit 1)
  );
end;
$$;
revoke all on function public.admin_home() from public, anon;
grant execute on function public.admin_home() to authenticated;

-- ── activity stream ────────────────────────────────────────────────────────
create function public.admin_activity(p_since timestamptz)
returns table (at timestamptz, kind text, severity text, title text,
               user_id uuid, cohort_id uuid, session_id uuid)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select * from (
      select p.created_at, 'signup'::text, 'info'::text,
             coalesce(p.handle, 'Someone') || ' created an account', p.id, null::uuid, null::uuid
        from public.profiles p
       where not p.is_guest and p.created_at > p_since
      union all
      select m.joined_at, 'class_join', 'ok',
             coalesce(m.roster_name, p.handle) || ' joined ' || c.name
               || case when m.role <> 'student' then ' as ' || m.role else '' end,
             m.user_id, m.cohort_id, null::uuid
        from public.cohort_members m
        join public.cohorts c on c.id = m.cohort_id
        left join public.profiles p on p.id = m.user_id
       where m.joined_at > p_since
      union all
      select lp.joined_at, 'live_join', 'ok',
             coalesce(lp.display_name, m.roster_name, p.handle, 'Guest')
               || ' joined live: ' || s.title,
             case when lp.is_guest then null else lp.user_id end, s.cohort_id, s.id
        from public.live_participants lp
        join public.live_sessions s on s.id = lp.session_id
        left join public.profiles p on p.id = lp.user_id
        left join public.cohort_members m
          on m.cohort_id = s.cohort_id and m.user_id = lp.user_id
       where lp.joined_at > p_since
      union all
      select s.created_at, 'session_start', 'info',
             'Live session started: ' || s.title || ' (' || c.name || ')',
             s.created_by, s.cohort_id, s.id
        from public.live_sessions s join public.cohorts c on c.id = s.cohort_id
       where s.created_at > p_since
      union all
      select s.ended_at, 'session_end', 'info',
             'Live session ended: ' || s.title, s.created_by, s.cohort_id, s.id
        from public.live_sessions s
       where s.ended_at is not null and s.ended_at > p_since
      union all
      select a.created_at, 'announcement', 'info',
             coalesce(p.handle, 'Someone') || ' messaged ' || c.name, a.author, a.cohort_id, null::uuid
        from public.class_announcements a
        join public.cohorts c on c.id = a.cohort_id
        left join public.profiles p on p.id = a.author
       where a.created_at > p_since
      union all
      select r.created_at, 'request', 'warn',
             coalesce(p.handle, 'Someone') || ' requested instructor access', r.user_id, null::uuid, null::uuid
        from public.faculty_access_requests r
        left join public.profiles p on p.id = r.user_id
       where r.created_at > p_since
      union all
      select o.created_at, 'problem', 'fail',
             replace(o.kind, '_', ' ') || coalesce(': ' || o.code, '')
               || coalesce(' (' || coalesce(p.handle, o.email) || ')', ''),
             o.user_id, null::uuid, null::uuid
        from app.ops_events o
        left join public.profiles p on p.id = o.user_id
       where o.kind <> 'app_seen' and o.created_at > p_since
    ) t(at, kind, severity, title, user_id, cohort_id, session_id)
    order by t.at desc
    limit 100;
end;
$$;
revoke all on function public.admin_activity(timestamptz) from public, anon;
grant execute on function public.admin_activity(timestamptz) to authenticated;

-- ── search ─────────────────────────────────────────────────────────────────
create function public.admin_search(p_q text)
returns table (kind text, id uuid, title text, subtitle text)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_q text := trim(coalesce(p_q, ''));
  v_esc text;
  v_like text;
  v_prefix text;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if length(v_q) < 2 then return; end if;
  v_esc := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_');
  v_like := '%' || v_esc || '%';
  v_prefix := v_esc || '%';
  -- Every column is selected with an explicit alias and every downstream
  -- reference is qualified by table: the function's own OUT parameters
  -- (kind, id, title, subtitle) are also valid plpgsql identifiers in this
  -- scope, and an unqualified "title" etc. is ambiguous against them.
  return query
    with ranked as (
      select x.kind, x.id, x.title, x.subtitle, x.rank from (
        select 'person'::text as kind, p.id as id,
               coalesce(r.names, p.handle) as title,
               coalesce(u.email, '') || ' · ' || p.handle as subtitle,
               case
                 when lower(u.email) = lower(v_q) or lower(p.handle) = lower(v_q)
                      or lower(r.names) = lower(v_q) then 0
                 when u.email ilike v_prefix or p.handle ilike v_prefix
                      or r.names ilike v_prefix then 1
                 else 2
               end as rank
          from public.profiles p
          join auth.users u on u.id = p.id
          left join lateral (
            select string_agg(distinct m.roster_name, ', ') names
              from public.cohort_members m
             where m.user_id = p.id and m.roster_name is not null) r on true
         where not p.is_guest
           and (u.email ilike v_like or p.handle ilike v_like or r.names ilike v_like)
        union all
        select 'class' as kind, c.id as id, c.name as title,
               coalesce(c.term, '') || ' · code ' || c.join_code as subtitle,
               case
                 when lower(c.name) = lower(v_q) or c.join_code = upper(v_q) then 0
                 when c.name ilike v_prefix then 1
                 else 2
               end as rank
          from public.cohorts c
         where c.name ilike v_like or c.join_code = upper(v_q)
        union all
        select 'session' as kind, s.id as id, s.title as title,
               c.name || ' · ' || s.status || ' · code ' || s.join_code as subtitle,
               case
                 when lower(s.title) = lower(v_q) or s.join_code = upper(v_q) then 0
                 when s.title ilike v_prefix then 1
                 else 2
               end as rank
          from public.live_sessions s join public.cohorts c on c.id = s.cohort_id
         where s.title ilike v_like or s.join_code = upper(v_q)
      ) x(kind, id, title, subtitle, rank)
    ),
    capped as (
      select ranked.kind as kind, ranked.id as id, ranked.title as title,
             ranked.subtitle as subtitle, ranked.rank as rank,
             row_number() over (
               partition by ranked.kind order by ranked.rank, ranked.title) as rn
        from ranked
    )
    select capped.kind, capped.id, capped.title, capped.subtitle
      from capped
     where capped.rn <= 10
     order by capped.rank, capped.kind, capped.title
     limit 25;
end;
$$;
revoke all on function public.admin_search(text) from public, anon;
grant execute on function public.admin_search(text) to authenticated;

-- ── records ────────────────────────────────────────────────────────────────
create function public.admin_person(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_email text;
  r jsonb;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  select u.email into v_email from auth.users u where u.id = p_user;
  perform app.audit('view_person', p_user);
  select jsonb_build_object(
    'identity', jsonb_build_object(
      'user_id', p.id, 'email', u.email, 'handle', p.handle, 'school', p.school,
      'created_at', u.created_at, 'last_sign_in_at', u.last_sign_in_at,
      'is_admin', app.is_admin(p.id), 'is_faculty', app.is_verified_faculty(p.id),
      'is_guest', p.is_guest),
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object('cohort_id', c.id, 'name', c.name,
               'term', c.term, 'role', m.role, 'roster_name', m.roster_name,
               'joined_at', m.joined_at) order by m.joined_at desc)
        from public.cohort_members m join public.cohorts c on c.id = m.cohort_id
       where m.user_id = p_user), '[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object('session_id', s.id, 'title', s.title,
               'cohort_id', s.cohort_id, 'class', c.name, 'joined_at', lp.joined_at,
               'answered', (select count(*) from public.live_answers a
                             where a.session_id = s.id and a.user_id = p_user),
               'correct', (select count(*) from public.live_answers a
                            where a.session_id = s.id and a.user_id = p_user
                              and a.correct)) order by lp.joined_at desc)
        from public.live_participants lp
        join public.live_sessions s on s.id = lp.session_id
        join public.cohorts c on c.id = s.cohort_id
       where lp.user_id = p_user), '[]'::jsonb),
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object('user_agent', left(se.user_agent, 160),
               'created_at', se.created_at, 'refreshed_at', se.refreshed_at)
               order by se.created_at desc)
        from auth.sessions se where se.user_id = p_user), '[]'::jsonb),
    'push_devices', (select count(*) from public.push_tokens t where t.user_id = p_user),
    'app_versions', coalesce((
      select jsonb_object_agg(x.client, x.app_version) from (
        select distinct on (o.client) o.client, o.app_version
          from app.ops_events o
         where o.user_id = p_user and o.kind = 'app_seen'
         order by o.client, o.created_at desc) x), '{}'::jsonb),
    'practice', (select jsonb_build_object('answers_30d', count(*),
                          'correct_30d', count(*) filter (where e.correct))
                   from public.events e
                  where e.user_id = p_user and e.type = 'answer'
                    and e.server_ts > now() - interval '30 days'),
    'timeline', coalesce((
      select jsonb_agg(t order by (t ->> 'at')::timestamptz desc) from (
        select t from (
          select jsonb_build_object('at', u.created_at, 'kind', 'account',
                   'title', 'Account created', 'detail', null, 'severity', 'info') t
          union all
          select jsonb_build_object('at', u.last_sign_in_at, 'kind', 'signin',
                   'title', 'Last sign-in', 'detail', null, 'severity', 'info')
           where u.last_sign_in_at is not null
          union all
          select jsonb_build_object('at', m.joined_at, 'kind', 'enroll',
                   'title', 'Joined ' || c.name || ' as ' || m.role,
                   'detail', m.roster_name, 'severity', 'ok')
            from public.cohort_members m join public.cohorts c on c.id = m.cohort_id
           where m.user_id = p_user
          union all
          select jsonb_build_object('at', lp.joined_at, 'kind', 'live_join',
                   'title', 'Joined live: ' || s.title, 'detail', c.name,
                   'severity', 'ok')
            from public.live_participants lp
            join public.live_sessions s on s.id = lp.session_id
            join public.cohorts c on c.id = s.cohort_id
           where lp.user_id = p_user
          union all
          select jsonb_build_object('at', max(a.created_at), 'kind', 'live_answers',
                   'title', count(*) filter (where a.correct) || ' of ' || count(*)
                            || ' correct in ' || s.title,
                   'detail', null, 'severity', 'info')
            from public.live_answers a join public.live_sessions s on s.id = a.session_id
           where a.user_id = p_user
           group by s.id, s.title
          union all
          select jsonb_build_object('at', max(e.server_ts), 'kind', 'practice',
                   'title', 'Answered ' || count(*) || ' questions ('
                            || count(*) filter (where e.correct) || ' correct)',
                   'detail', to_char(date_trunc('day', e.server_ts), 'YYYY-MM-DD'),
                   'severity', 'info')
            from public.events e
           where e.user_id = p_user and e.type = 'answer'
           group by date_trunc('day', e.server_ts)
          union all
          select jsonb_build_object('at', e.server_ts, 'kind', 'mock',
                   'title', 'Started a mock exam', 'detail', null, 'severity', 'info')
            from public.events e where e.user_id = p_user and e.type = 'mock_start'
          union all
          select jsonb_build_object('at', max(e.server_ts), 'kind', 'session_start',
                   'title', case when count(*) = 1 then 'Started a study session'
                                 else 'Studied ' || count(*) || ' sessions' end,
                   'detail', to_char(date_trunc('day', e.server_ts), 'YYYY-MM-DD'),
                   'severity', 'info')
            from public.events e
           where e.user_id = p_user and e.type = 'session_start'
           group by date_trunc('day', e.server_ts)
          union all
          select jsonb_build_object('at', v.created_at, 'kind', 'faculty',
                   'title', 'Verified as an instructor', 'detail', v.note,
                   'severity', 'ok')
            from app.verified_faculty v where v.user_id = p_user
          union all
          select jsonb_build_object('at', r2.created_at, 'kind', 'request',
                   'title', 'Requested instructor access (' || r2.status || ')',
                   'detail', r2.school || ', ' || r2.courses, 'severity', 'warn')
            from public.faculty_access_requests r2 where r2.user_id = p_user
          union all
          select jsonb_build_object('at', a.created_at, 'kind', 'announcement',
                   'title', 'Messaged ' || c.name, 'detail', left(a.body, 120),
                   'severity', 'info')
            from public.class_announcements a join public.cohorts c on c.id = a.cohort_id
           where a.author = p_user
          union all
          select jsonb_build_object('at', x.created_at, 'kind', 'export',
                   'title', 'Exported ' || replace(x.kind, '_', ' '),
                   'detail', null, 'severity', 'info')
            from app.export_log x where x.user_id = p_user
          union all
          select jsonb_build_object('at', o.created_at,
                   'kind', case when o.kind = 'app_seen' then 'app_seen' else 'problem' end,
                   'title', case when o.kind = 'app_seen'
                                 then 'Opened the ' || o.client || ' app '
                                      || coalesce(o.app_version, '')
                                 else replace(o.kind, '_', ' ')
                                      || coalesce(': ' || o.code, '') end,
                   'detail', o.detail,
                   'severity', case when o.kind = 'app_seen' then 'info' else 'fail' end)
            from app.ops_events o
           where o.user_id = p_user or (v_email is not null and o.email = lower(v_email))
          union all
          select jsonb_build_object('at', au.created_at, 'kind', 'audit',
                   'title', coalesce(ap.handle, 'An admin') || ': '
                            || replace(au.action, '_', ' '),
                   'detail', au.details, 'severity', 'info')
            from app.admin_audit au left join public.profiles ap on ap.id = au.actor
           where au.target_user = p_user and au.action <> 'view_person'
        ) all_rows
        where (t ->> 'at') is not null
        order by (t ->> 'at')::timestamptz desc
        limit 300) lim), '[]'::jsonb)
  ) into r
  from public.profiles p join auth.users u on u.id = p.id
  where p.id = p_user;
  if r is null then raise exception 'no such person'; end if;
  return r;
end;
$$;
revoke all on function public.admin_person(uuid) from public, anon;
grant execute on function public.admin_person(uuid) to authenticated;

create function public.admin_class(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare r jsonb;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  select jsonb_build_object(
    'facts', jsonb_build_object('cohort_id', c.id, 'name', c.name, 'term', c.term,
      'join_code', c.join_code, 'owner', op.handle, 'created_at', c.created_at,
      'reporting_resolution', c.reporting_resolution, 'is_demo', c.is_demo),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'handle', p.handle,
               'email', u.email, 'role', m.role, 'roster_name', m.roster_name,
               'joined_at', m.joined_at,
               'last_active', (select max(e.server_ts) from public.events e
                                where e.user_id = m.user_id and e.cohort_id = c.id))
               order by m.role, coalesce(m.roster_name, p.handle))
        from public.cohort_members m
        left join public.profiles p on p.id = m.user_id
        left join auth.users u on u.id = m.user_id
       where m.cohort_id = c.id), '[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object('session_id', s.id, 'title', s.title,
               'status', s.status, 'created_at', s.created_at, 'ended_at', s.ended_at,
               'participants', (select count(*) from public.live_participants lp
                                 where lp.session_id = s.id),
               'answers', (select count(*) from public.live_answers a
                            where a.session_id = s.id)) order by s.created_at desc)
        from public.live_sessions s where s.cohort_id = c.id), '[]'::jsonb),
    'funnel', jsonb_build_object(
      'members', (select count(*) from public.cohort_members m where m.cohort_id = c.id),
      'students', (select count(*) from public.cohort_members m
                    where m.cohort_id = c.id and m.role = 'student'),
      'answered_live', (select count(distinct a.user_id) from public.live_answers a
                          join public.live_sessions s on s.id = a.session_id
                          join public.cohort_members m
                            on m.cohort_id = c.id and m.user_id = a.user_id
                           and m.role = 'student'
                         where s.cohort_id = c.id),
      'practiced_7d', (select count(distinct e.user_id) from public.events e
                         join public.cohort_members m
                           on m.cohort_id = c.id and m.user_id = e.user_id
                          and m.role = 'student'
                        where e.cohort_id = c.id
                          and e.server_ts > now() - interval '7 days')),
    'timeline', coalesce((
      select jsonb_agg(t order by (t ->> 'at')::timestamptz desc) from (
        select t from (
          select jsonb_build_object('at', c.created_at, 'kind', 'class',
                   'title', 'Class created by ' || coalesce(op.handle, 'unknown'),
                   'detail', null, 'severity', 'info') t
          union all
          select jsonb_build_object('at', m.joined_at, 'kind', 'enroll',
                   'title', coalesce(m.roster_name, p.handle) || ' joined as ' || m.role,
                   'detail', null, 'severity', 'ok')
            from public.cohort_members m left join public.profiles p on p.id = m.user_id
           where m.cohort_id = c.id
          union all
          select jsonb_build_object('at', s.created_at, 'kind', 'session_start',
                   'title', 'Live session started: ' || s.title, 'detail', null,
                   'severity', 'info')
            from public.live_sessions s where s.cohort_id = c.id
          union all
          select jsonb_build_object('at', s.ended_at, 'kind', 'session_end',
                   'title', 'Live session ended: ' || s.title, 'detail', null,
                   'severity', 'info')
            from public.live_sessions s where s.cohort_id = c.id and s.ended_at is not null
          union all
          select jsonb_build_object('at', a.created_at, 'kind', 'announcement',
                   'title', 'Message sent', 'detail', left(a.body, 120),
                   'severity', 'info')
            from public.class_announcements a where a.cohort_id = c.id
          union all
          select jsonb_build_object('at', au.created_at, 'kind', 'audit',
                   'title', coalesce(ap.handle, 'An admin') || ': '
                            || replace(au.action, '_', ' '),
                   'detail', au.details, 'severity', 'info')
            from app.admin_audit au left join public.profiles ap on ap.id = au.actor
           where au.target_cohort = c.id
        ) all_rows
        order by (t ->> 'at')::timestamptz desc
        limit 300) lim), '[]'::jsonb)
  ) into r
  from public.cohorts c left join public.profiles op on op.id = c.created_by
  where c.id = p_cohort;
  if r is null then raise exception 'no such class'; end if;
  return r;
end;
$$;
revoke all on function public.admin_class(uuid) from public, anon;
grant execute on function public.admin_class(uuid) to authenticated;

create function public.admin_session(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare r jsonb;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  select jsonb_build_object(
    'facts', jsonb_build_object('session_id', s.id, 'title', s.title,
      'cohort_id', s.cohort_id, 'class', c.name, 'professor', pp.handle,
      'status', s.status, 'index', s.current_index,
      'total', jsonb_array_length(s.question_ids),
      'question_seconds', s.question_seconds, 'join_code', s.join_code,
      'allow_guests', s.allow_guests, 'created_at', s.created_at,
      'ended_at', s.ended_at),
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', lp.user_id,
               'name', coalesce(lp.display_name, m.roster_name, p.handle, 'Guest'),
               'is_guest', lp.is_guest, 'joined_at', lp.joined_at,
               'answered', (select count(*) from public.live_answers a
                             where a.session_id = s.id and a.user_id = lp.user_id),
               'correct', (select count(*) from public.live_answers a
                            where a.session_id = s.id and a.user_id = lp.user_id
                              and a.correct)) order by lp.joined_at)
        from public.live_participants lp
        left join public.profiles p on p.id = lp.user_id
        left join public.cohort_members m
          on m.cohort_id = s.cohort_id and m.user_id = lp.user_id
       where lp.session_id = s.id), '[]'::jsonb),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object('position', ids.ord, 'question_id', q.id,
               'stem', left(q.stem, 160),
               'answered', (select count(*) from public.live_answers a
                             where a.session_id = s.id and a.question_id = q.id),
               'correct_rate', (select avg(a.correct::int)::real from public.live_answers a
                                 where a.session_id = s.id and a.question_id = q.id))
               order by ids.ord)
        from jsonb_array_elements_text(s.question_ids) with ordinality ids(qid, ord)
        join public.questions q on q.id = ids.qid::uuid), '[]'::jsonb),
    'timeline', coalesce((
      select jsonb_agg(t order by (t ->> 'at')::timestamptz desc) from (
        select t from (
          select jsonb_build_object('at', s.created_at, 'kind', 'session_start',
                   'title', 'Session created by ' || coalesce(pp.handle, 'unknown'),
                   'detail', null, 'severity', 'info') t
          union all
          select jsonb_build_object('at', lp.joined_at, 'kind', 'live_join',
                   'title', coalesce(lp.display_name, m.roster_name, p.handle, 'Guest')
                            || ' joined',
                   'detail', null, 'severity', 'ok')
            from public.live_participants lp
            left join public.profiles p on p.id = lp.user_id
            left join public.cohort_members m
              on m.cohort_id = s.cohort_id and m.user_id = lp.user_id
           where lp.session_id = s.id
          union all
          select jsonb_build_object('at', min(a.created_at), 'kind', 'question',
                   'title', 'Question answered by ' || count(*) || ' ('
                            || count(*) filter (where a.correct) || ' correct)',
                   'detail', left(q.stem, 120), 'severity', 'info')
            from public.live_answers a join public.questions q on q.id = a.question_id
           where a.session_id = s.id
           group by q.id, q.stem
          union all
          select jsonb_build_object('at', s.ended_at, 'kind', 'session_end',
                   'title', 'Session ended', 'detail', null, 'severity', 'info')
           where s.ended_at is not null
          union all
          select jsonb_build_object('at', au.created_at, 'kind', 'audit',
                   'title', coalesce(ap.handle, 'An admin') || ': '
                            || replace(au.action, '_', ' '),
                   'detail', au.details, 'severity', 'info')
            from app.admin_audit au left join public.profiles ap on ap.id = au.actor
           where au.target_session = s.id
        ) all_rows
        order by (t ->> 'at')::timestamptz desc
        limit 300) lim), '[]'::jsonb)
  ) into r
  from public.live_sessions s
  join public.cohorts c on c.id = s.cohort_id
  left join public.profiles pp on pp.id = s.created_by
  where s.id = p_session;
  if r is null then raise exception 'no such session'; end if;
  return r;
end;
$$;
revoke all on function public.admin_session(uuid) from public, anon;
grant execute on function public.admin_session(uuid) to authenticated;

create function public.admin_console_open() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if exists (select 1 from app.admin_audit
              where actor = auth.uid() and action = 'console_open'
                and created_at > now() - interval '10 minutes') then
    return;
  end if;
  perform app.audit('console_open');
end;
$$;
revoke all on function public.admin_console_open() from public, anon;
grant execute on function public.admin_console_open() to authenticated;

-- ── admin writes (2a) ──────────────────────────────────────────────────────
create function public.admin_set_faculty_audited(p_user uuid, p_verified boolean)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if p_verified then
    insert into app.verified_faculty (user_id, granted_by, note)
    values (p_user, auth.uid(), 'granted in the admin console')
    on conflict (user_id) do nothing;
    -- Only audit a real change: ON CONFLICT DO NOTHING leaves FOUND false.
    if found then
      perform app.audit('faculty_granted', p_user);
    end if;
  else
    delete from app.verified_faculty where user_id = p_user;
    -- Only audit a real change: nothing to delete leaves FOUND false.
    if found then
      perform app.audit('faculty_revoked', p_user);
    end if;
  end if;
end;
$$;
revoke all on function public.admin_set_faculty_audited(uuid, boolean) from public, anon;
grant execute on function public.admin_set_faculty_audited(uuid, boolean) to authenticated;

create function public.admin_list_invites_v2()
returns table (code text, note text, minted_by_handle text, recipient_email text,
               uses int, max_uses int, created_at timestamptz,
               expires_at timestamptz, revoked_at timestamptz, status text)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select i.code, i.note, p.handle, i.recipient_email, i.uses, i.max_uses,
           i.created_at, i.expires_at, i.revoked_at,
           case when i.revoked_at is not null then 'revoked'
                when i.uses >= i.max_uses then 'used'
                when i.expires_at <= now() then 'expired'
                else 'active' end
      from public.faculty_invites i
      left join public.profiles p on p.id = i.minted_by
     order by i.created_at desc;
end;
$$;
revoke all on function public.admin_list_invites_v2() from public, anon;
grant execute on function public.admin_list_invites_v2() to authenticated;

create function public.admin_mint_invite(
  p_note text default null, p_recipient_email text default null
) returns text
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_code text;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  v_code := public.mint_faculty_invite(p_note, p_recipient_email);
  perform app.audit('invite_minted', null, null, null,
    jsonb_build_object('code', v_code,
      'recipient', nullif(lower(trim(coalesce(p_recipient_email, ''))), '')));
  return v_code;
end;
$$;
revoke all on function public.admin_mint_invite(text, text) from public, anon;
grant execute on function public.admin_mint_invite(text, text) to authenticated;

create function public.admin_revoke_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_already_revoked boolean;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  -- An already-revoked invite is a no-op: revoke_faculty_invite's own
  -- coalesce() would happily succeed again, which used to audit the same
  -- revocation twice. Check first and return quietly when there is nothing
  -- new to do; an unknown code still falls through to the RPC's own error.
  select revoked_at is not null into v_already_revoked
    from public.faculty_invites where code = upper(trim(p_code));
  if v_already_revoked then
    return;
  end if;
  perform public.revoke_faculty_invite(p_code);
  perform app.audit('invite_revoked', null, null, null,
    jsonb_build_object('code', upper(trim(p_code))));
end;
$$;
revoke all on function public.admin_revoke_invite(text) from public, anon;
grant execute on function public.admin_revoke_invite(text) to authenticated;

create function public.admin_audit_list(p_action text default null, p_limit int default 200)
returns table (id bigint, created_at timestamptz, actor_handle text, action text,
               target_user uuid, target_label text, target_cohort uuid,
               target_session uuid, details jsonb)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select a.id, a.created_at, ap.handle, a.action, a.target_user,
           coalesce(tp.handle, c.name, s.title), a.target_cohort, a.target_session,
           a.details
      from app.admin_audit a
      left join public.profiles ap on ap.id = a.actor
      left join public.profiles tp on tp.id = a.target_user
      left join public.cohorts c on c.id = a.target_cohort
      left join public.live_sessions s on s.id = a.target_session
     where p_action is null or a.action = p_action
     order by a.created_at desc
     limit least(greatest(coalesce(p_limit, 200), 1), 500);
end;
$$;
revoke all on function public.admin_audit_list(text, int) from public, anon;
grant execute on function public.admin_audit_list(text, int) to authenticated;

-- ── decommission the legacy unaudited admin write ─────────────────────────
-- public.admin_set_faculty(uuid, boolean) predates admin_set_faculty_audited.
-- It is admin-gated but writes no audit row. Its only caller, the legacy
-- admin tab, is gone, so no client role may call it any more.
revoke all on function public.admin_set_faculty(uuid, boolean)
  from public, anon, authenticated;
