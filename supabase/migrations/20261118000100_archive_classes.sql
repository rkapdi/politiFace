-- Archiving classes: an admin hides a class that is no longer relevant
-- (a test class, a duplicate section) from the console without deleting
-- anything, and can restore it. Only an archived class can be deleted
-- permanently, and only by an admin who types its name.
--
-- What archiving changes:
--   * The admin home (totals, class list, alerts), the operating picture
--     and the on-track number leave archived classes out.
--   * Instructors no longer see an archived class under "Your classes".
--   * Admin search still finds it, marked "archived", so it can be restored
--     or deleted from its record page.
-- What it does not change: members stay enrolled, students keep their
-- practice, and nothing is deleted. Students' own screens are unchanged.
--
-- The functions below that already existed are copied from their latest
-- migration; the only change in each is the archived_at filter (and, in
-- admin_class, two new facts).

alter table public.cohorts
  add column archived_at timestamptz,
  add column archived_by uuid references public.profiles (id) on delete set null;

-- ── archive and restore ─────────────────────────────────────────────────────
-- Returns {"cohort_id", "archived_at"}; archived_at is null after a restore.
create function public.admin_archive_class(p_cohort uuid, p_archive boolean)
returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_name text;
  v_at   timestamptz;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  update public.cohorts
     set archived_at = case when p_archive then coalesce(archived_at, now()) end,
         archived_by = case when p_archive then coalesce(archived_by, auth.uid()) end
   where id = p_cohort
  returning name, archived_at into v_name, v_at;
  if not found then raise exception 'no such class'; end if;
  perform app.audit(case when p_archive then 'class_archived' else 'class_restored' end,
                    null, p_cohort, null, jsonb_build_object('name', v_name));
  return jsonb_build_object('cohort_id', p_cohort, 'archived_at', v_at);
end;
$$;
revoke all on function public.admin_archive_class(uuid, boolean) from public, anon;
grant execute on function public.admin_archive_class(uuid, boolean) to authenticated;

-- ── delete permanently ──────────────────────────────────────────────────────
-- Refuses unless the class is archived and p_confirm_name is its exact
-- name. Members, live sessions and their answers, saved sessions,
-- messages and the class's read models go with it (on delete cascade).
-- Students' own practice answers and practice tests are kept, without the
-- class. A class with questions of its own is refused: those questions are
-- part of students' answer history.
create function public.admin_delete_class(p_cohort uuid, p_confirm_name text)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  c public.cohorts%rowtype;
  v_members int;
  v_sessions int;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  select * into c from public.cohorts where id = p_cohort for update;
  if not found then raise exception 'no such class'; end if;
  if c.archived_at is null then
    raise exception 'archive the class before deleting it';
  end if;
  if trim(coalesce(p_confirm_name, '')) <> c.name then
    raise exception 'type the class name exactly to delete it';
  end if;
  if exists (select 1 from public.live_sessions s
              where s.cohort_id = p_cohort and s.status <> 'ended') then
    raise exception 'end the class''s live session before deleting it';
  end if;
  if exists (select 1 from public.questions q where q.cohort_id = p_cohort) then
    raise exception 'this class has questions of its own and cannot be deleted';
  end if;

  select count(*) into v_members from public.cohort_members where cohort_id = p_cohort;
  select count(*) into v_sessions from public.live_sessions where cohort_id = p_cohort;

  update public.events set cohort_id = null where cohort_id = p_cohort;
  update public.mock_attempts set cohort_id = null where cohort_id = p_cohort;
  update public.user_domain_readiness set cohort_id = null where cohort_id = p_cohort;
  update public.user_objective_readiness set cohort_id = null where cohort_id = p_cohort;
  update public.redemption_codes set cohort_id = null where cohort_id = p_cohort;
  delete from public.cohorts where id = p_cohort;

  perform app.audit('class_deleted', null, p_cohort, null,
    jsonb_build_object('name', c.name, 'term', c.term, 'members', v_members,
                       'live_sessions', v_sessions));
end;
$$;
revoke all on function public.admin_delete_class(uuid, text) from public, anon;
grant execute on function public.admin_delete_class(uuid, text) to authenticated;

-- ── existing functions, now leaving archived classes out ────────────────────

create or replace function public.admin_home() returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return jsonb_build_object(
    'totals', jsonb_build_object(
      'people', (select count(*) from public.profiles where not is_guest),
      'students', (select count(distinct user_id) from public.cohort_members
                    where role = 'student'),
      'faculty', (select count(*) from app.verified_faculty),
      'classes', (select count(*) from public.cohorts
                    where archived_at is null),
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
          from public.cohorts c
         where c.archived_at is null) x), '[]'::jsonb),
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
                  from public.cohorts c
                 where c.archived_at is null) cs
         where cs.st >= 5 and cs.act * 2 < cs.st
        union all
        select jsonb_build_object('kind', 'duplicates', 'severity', 'warn',
                 'cohort_id', m.cohort_id,
                 'title', (select name from public.cohorts where id = m.cohort_id)
                          || ': "' || min(m.roster_name) || '" is listed '
                          || count(*) || ' times')
          from public.cohort_members m
         where m.role = 'student' and m.roster_name is not null
           and not exists (select 1 from public.cohorts ac
                            where ac.id = m.cohort_id and ac.archived_at is not null)
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

create or replace function public.admin_search(p_q text)
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
               case when c.archived_at is not null then 'archived · ' else '' end
                 || coalesce(c.term, '') || ' · code ' || c.join_code as subtitle,
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

create or replace function public.admin_class(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare r jsonb;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  select jsonb_build_object(
    'facts', jsonb_build_object('cohort_id', c.id, 'name', c.name, 'term', c.term,
      'join_code', c.join_code, 'owner', op.handle, 'created_at', c.created_at,
      'reporting_resolution', c.reporting_resolution, 'is_demo', c.is_demo,
      'archived_at', c.archived_at,
      'archived_by', (select ap.handle from public.profiles ap
                       where ap.id = c.archived_by)),
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

create or replace function app.on_track_now()
returns table (students int, on_track int)
language sql stable security definer set search_path = public, app, pg_temp as $$
  select count(*)::int,
         (count(*) filter (where app.projected_mid(s.user_id) >= 48))::int
    from (select distinct m.user_id
            from public.cohort_members m
            join public.cohorts c on c.id = m.cohort_id
           where m.role = 'student' and not c.is_demo
             and c.archived_at is null) s;
$$;

create or replace function public.admin_picture(p_tz text default 'UTC') returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_tz text := coalesce(nullif(trim(p_tz), ''), 'UTC');
  v_today date;
  v_from date;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if not exists (select 1 from pg_timezone_names where name = v_tz) then
    v_tz := 'UTC';
  end if;
  v_today := (now() at time zone v_tz)::date;
  v_from := v_today - 13;

  return (
    with mids as materialized (
      select s.user_id, app.projected_mid(s.user_id) as mid
        from (select distinct user_id from public.cohort_members
               where role = 'student') s
    ),
    real_students as (
      select distinct m.user_id
        from public.cohort_members m
        join public.cohorts c on c.id = m.cohort_id
       where m.role = 'student' and not c.is_demo
         and c.archived_at is null
    ),
    ev as materialized (
      select (e.server_ts at time zone v_tz)::date as day, e.user_id, e.type
        from public.events e
        left join public.cohorts c on c.id = e.cohort_id
       where e.server_ts >= (v_from::timestamp at time zone v_tz)
         and not coalesce(c.is_demo, false)
         and c.archived_at is null
    ),
    -- Live answers from signed-in students are folded into events when a
    -- session ends, so events alone cover practice and live.
    ans as materialized (
      select e.question_id, e.chosen_key, e.correct
        from public.events e
        left join public.cohorts c on c.id = e.cohort_id
       where e.type = 'answer' and e.correct is not null
         and e.server_ts > now() - interval '60 days'
         and not coalesce(c.is_demo, false)
         and c.archived_at is null
    ),
    qstats as (
      select a.question_id, count(*) as n, avg(a.correct::int) as rate
        from ans a
       group by a.question_id
      having count(*) >= 20 and avg(a.correct::int) < 0.35
       order by avg(a.correct::int), count(*) desc
       limit 5
    )
    select jsonb_build_object(
      'tz', v_tz,
      'now', (
        select jsonb_build_object(
                 'students', count(*),
                 'on_track', count(*) filter (where mi.mid >= 48),
                 'practised_7d', count(*) filter (where exists (
                   select 1 from public.events e
                    where e.user_id = rs.user_id
                      and e.server_ts > now() - interval '7 days')),
                 'live_7d', count(*) filter (where exists (
                   select 1 from public.live_answers a
                    where a.user_id = rs.user_id
                      and a.created_at > now() - interval '7 days')))
          from real_students rs
          left join mids mi on mi.user_id = rs.user_id),
      'classes', coalesce((
        select jsonb_agg(k order by k ->> 'name') from (
          select jsonb_build_object(
                   'cohort_id', c.id, 'name', c.name, 'term', c.term,
                   'is_demo', c.is_demo,
                   'students', (select count(*) from public.cohort_members m
                                 where m.cohort_id = c.id and m.role = 'student'),
                   'on_track', (select count(*) from public.cohort_members m
                                  join mids mi on mi.user_id = m.user_id
                                 where m.cohort_id = c.id and m.role = 'student'
                                   and mi.mid >= 48),
                   'practised_7d', (select count(distinct e.user_id)
                                      from public.events e
                                      join public.cohort_members m
                                        on m.cohort_id = c.id
                                       and m.user_id = e.user_id
                                       and m.role = 'student'
                                     where e.cohort_id = c.id
                                       and e.server_ts > now() - interval '7 days'),
                   'last_live_at', (select max(s.created_at)
                                      from public.live_sessions s
                                     where s.cohort_id = c.id)) k
            from public.cohorts c
           where c.archived_at is null) x), '[]'::jsonb),
      'days', (
        select jsonb_agg(jsonb_build_object(
                 'day', d.day,
                 'answers', (select count(*) from ev
                              where ev.day = d.day
                                and ev.type in ('answer', 'review')),
                 'practising', (select count(distinct ev.user_id) from ev
                                 where ev.day = d.day),
                 'live_sessions', (select count(*)
                                     from public.live_sessions s
                                     join public.cohorts c on c.id = s.cohort_id
                                    where (s.created_at at time zone v_tz)::date = d.day
                                      and not c.is_demo
                                      and c.archived_at is null),
                 'actions', (select count(*) from app.admin_audit a
                              where (a.created_at at time zone v_tz)::date = d.day
                                and a.action not in ('console_open', 'view_person')),
                 'students', o.students,
                 'on_track', o.on_track) order by d.day)
          from (select g::date as day
                  from generate_series(v_from, v_today, interval '1 day') g) d
          left join app.on_track_daily o on o.day = d.day),
      'questions', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'question_id', q.id,
                 'stem', left(q.stem, 160),
                 'answers', qs.n,
                 'correct_rate', round(qs.rate::numeric, 3),
                 'top_wrong', (
                   select jsonb_build_object(
                            'key', w.chosen_key,
                            'share', round(w.n::numeric / qs.n, 3))
                     from (select a.chosen_key, count(*) as n
                             from ans a
                            where a.question_id = q.id and not a.correct
                            group by a.chosen_key
                            order by count(*) desc, a.chosen_key
                            limit 1) w)) order by qs.rate, qs.n desc)
          from qstats qs
          join public.questions q on q.id = qs.question_id), '[]'::jsonb)
    )
  );
end;
$$;

create or replace function public.my_faculty_overview()
returns table (
  cohort_id uuid, name text, term text, students bigint,
  active_7d bigint, answers_total bigint, accuracy real,
  mocks_completed bigint, live_sessions bigint
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  return query
    select c.id, c.name, c.term,
           (select count(*) from public.cohort_members m
             where m.cohort_id = c.id and m.role = 'student') as students,
           case when app.cohort_student_count(c.id) >= app.aggregate_floor(c.id) then
             (select count(distinct e.user_id) from public.events e
               where e.cohort_id = c.id
                 and e.server_ts > now() - interval '7 days')
           end,
           case when app.cohort_student_count(c.id) >= app.aggregate_floor(c.id) then
             (select count(*) from public.events e
               where e.cohort_id = c.id and e.type = 'answer'
                 and e.correct is not null)
           end,
           case when app.cohort_student_count(c.id) >= app.aggregate_floor(c.id) then
             (select avg(e.correct::int)::real from public.events e
               where e.cohort_id = c.id and e.type = 'answer'
                 and e.correct is not null)
           end,
           case when app.cohort_student_count(c.id) >= app.aggregate_floor(c.id) then
             (select count(*) from public.mock_attempts a
               where a.cohort_id = c.id and a.completed_at is not null)
           end,
           (select count(*) from public.live_sessions s
             where s.cohort_id = c.id and s.status = 'ended')
      from public.cohorts c
     where app.is_cohort_ta_or_above(c.id)
       and c.archived_at is null
     order by c.created_at desc;
end;
$$;
