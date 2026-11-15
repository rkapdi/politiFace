-- Admin console home, the "operating picture": one outcome number (the
-- share of students who project above the pass line), the last 14 days of
-- activity behind it, and the facts the decisions queue is built from.
--
-- Everything here is admin-only and read-only apart from one small daily
-- snapshot table, which exists because the projection model has no history:
-- app.projected_mid() answers "now" only, so a trend needs a stored point
-- per day. Demo classes are left out of every system-wide number.

-- ── daily snapshot of the outcome number ───────────────────────────────────
-- Aggregate only: two counts per day, no per-student rows.
create table app.on_track_daily (
  day         date primary key,
  students    int not null check (students >= 0),
  on_track    int not null check (on_track >= 0 and on_track <= students),
  captured_at timestamptz not null default now()
);
-- Written by the cron job below and read only through admin_picture().
alter table app.on_track_daily enable row level security;

-- Same rule the class pulse uses: a projected score of 48 of 80 or more.
-- A student in two classes counts once.
create function app.on_track_now()
returns table (students int, on_track int)
language sql stable security definer set search_path = public, app, pg_temp as $$
  select count(*)::int,
         (count(*) filter (where app.projected_mid(s.user_id) >= 48))::int
    from (select distinct m.user_id
            from public.cohort_members m
            join public.cohorts c on c.id = m.cohort_id
           where m.role = 'student' and not c.is_demo) s;
$$;

create function app.snapshot_on_track() returns void
language sql security definer set search_path = public, app, pg_temp as $$
  insert into app.on_track_daily (day, students, on_track)
  select (now() at time zone 'utc')::date, n.students, n.on_track
    from app.on_track_now() n
  on conflict (day) do update
    set students = excluded.students,
        on_track = excluded.on_track,
        captured_at = now();
$$;

-- Late in the UTC day, so each row is that day's closing value.
do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'on-track snapshot cron: pg_cron not installed; skipping';
    return;
  end if;
  if exists (select 1 from cron.job where jobname = 'snapshot-on-track') then
    perform cron.unschedule('snapshot-on-track');
  end if;
  perform cron.schedule('snapshot-on-track', '53 23 * * *',
    'select app.snapshot_on_track()');
end $$;

-- ── the picture ────────────────────────────────────────────────────────────
-- p_tz is the viewer's time zone, so a "day" is their day. An unknown zone
-- falls back to UTC rather than failing. Snapshot days are UTC days.
create function public.admin_picture(p_tz text default 'UTC') returns jsonb
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
    ),
    ev as materialized (
      select (e.server_ts at time zone v_tz)::date as day, e.user_id, e.type
        from public.events e
        left join public.cohorts c on c.id = e.cohort_id
       where e.server_ts >= (v_from::timestamp at time zone v_tz)
         and not coalesce(c.is_demo, false)
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
            from public.cohorts c) x), '[]'::jsonb),
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
                                      and not c.is_demo),
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
revoke all on function public.admin_picture(text) from public, anon;
grant execute on function public.admin_picture(text) to authenticated;
