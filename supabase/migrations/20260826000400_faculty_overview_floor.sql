-- The classes dashboard joins per-student-first: my_faculty_overview was
-- missed in 20260826000200 and still used a hard-coded 5-student floor,
-- so the class CARDS said "stats appear at 5 students" while the class
-- detail pages showed everything. Same dynamic floor everywhere now.
-- Body from 20260821000100; only the floor comparisons change.

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
     order by c.created_at desc;
end;
$$;
