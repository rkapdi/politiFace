-- Faculty aggregates (Epic 7a): the cohort weakness view.
--
-- Faculty never read raw student events; these SECURITY DEFINER functions
-- are the only path, and they return cohort AGGREGATES only. A minimum-n
-- floor (default 5 students) keeps small slices from identifying anyone:
-- below the floor the functions return nothing rather than a statistic.
--
-- Also: create_cohort, so the faculty web page can mint a class + join
-- code without relying on RETURNING under RLS timing.

-- ── create_cohort ───────────────────────────────────────────────────────────
create function public.create_cohort(p_name text, p_term text default null)
returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
  v_code text;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if length(trim(coalesce(p_name, ''))) < 3 then
    raise exception 'class name too short';
  end if;
  insert into public.cohorts (name, term, created_by)
  values (trim(p_name), nullif(trim(coalesce(p_term, '')), ''), v_user)
  returning id, join_code into v_id, v_code;
  return jsonb_build_object('id', v_id, 'join_code', v_code);
end;
$$;

-- ── cohort_overview ─────────────────────────────────────────────────────────
create function public.cohort_overview(p_cohort uuid)
returns table (
  students        int,
  active_7d       int,
  answers_total   int,
  mocks_completed int
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query select
    (select count(*)::int from public.cohort_members m
      where m.cohort_id = p_cohort and m.role = 'student'),
    (select count(distinct e.user_id)::int from public.events e
      where e.cohort_id = p_cohort and e.server_ts > now() - interval '7 days'),
    (select count(*)::int from public.events e
      where e.cohort_id = p_cohort and e.type = 'answer'
        and e.correct is not null),
    (select count(*)::int from public.mock_attempts a
      where a.cohort_id = p_cohort and a.completed_at is not null);
end;
$$;

-- ── cohort_domain_stats ─────────────────────────────────────────────────────
-- Per-domain accuracy across the cohort. Rows appear only once at least
-- p_min_n distinct students have answered in that domain.
create function public.cohort_domain_stats(p_cohort uuid, p_min_n int default 5)
returns table (
  domain_code text,
  domain_name text,
  students    int,
  answers     int,
  accuracy    real
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select d.code,
           d.name,
           count(distinct e.user_id)::int,
           count(*)::int,
           avg(e.correct::int)::real
    from public.events e
    join public.domains d on d.id = e.domain_id
    where e.cohort_id = p_cohort
      and e.type = 'answer'
      and e.correct is not null
    group by d.code, d.name, d.ordinal
    having count(distinct e.user_id) >= greatest(p_min_n, 1)
    order by d.ordinal;
end;
$$;

-- ── cohort_top_misses ───────────────────────────────────────────────────────
-- The questions the cohort gets wrong most, with stems, for "here is where
-- my class is weak". Same min-n floor per question.
create function public.cohort_top_misses(
  p_cohort uuid,
  p_min_n  int default 5,
  p_limit  int default 10
)
returns table (
  question_id uuid,
  stem        text,
  domain_code text,
  students    int,
  attempts    int,
  miss_rate   real
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select q.id,
           q.stem,
           d.code,
           count(distinct e.user_id)::int,
           count(*)::int,
           (1.0 - avg(e.correct::int))::real
    from public.events e
    join public.questions q on q.id = e.question_id
    join public.domains d on d.id = q.domain_id
    where e.cohort_id = p_cohort
      and e.type = 'answer'
      and e.correct is not null
    group by q.id, q.stem, d.code
    having count(distinct e.user_id) >= greatest(p_min_n, 1)
       and avg(e.correct::int) < 1.0
    order by (1.0 - avg(e.correct::int)) desc, count(*) desc
    limit greatest(p_limit, 1);
end;
$$;

-- ── grants ──────────────────────────────────────────────────────────────────
revoke execute on function
  public.create_cohort(text, text),
  public.cohort_overview(uuid),
  public.cohort_domain_stats(uuid, int),
  public.cohort_top_misses(uuid, int, int)
from public, anon;

grant execute on function
  public.create_cohort(text, text),
  public.cohort_overview(uuid),
  public.cohort_domain_stats(uuid, int),
  public.cohort_top_misses(uuid, int, int)
to authenticated;
