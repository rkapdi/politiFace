-- No course identifiers in class names or live-session titles.
--
-- Faculty requirement for running live sessions: nothing students see may
-- tie a class to the school's course catalog. Class names and session
-- titles may not contain:
--   * a course code: 3 letters then 4 digits, with an optional space, dash
--     or underscore and an optional trailing letter ("POS 2041",
--     "POS2041", "INR_2002", "BSC 1010C");
--   * a run of 4 or more digits (CRNs such as 8334 or 88334; the term
--     belongs in the cohort's term field, not the name).
-- Short numbers stay allowed ("Section 2", "Period 3").
--
-- Enforced as CHECK constraints so it holds for every write path (RPCs,
-- the legacy /faculty portal, direct updates under RLS). Official course
-- titles cannot be detected reliably; the console's guidance copy covers
-- them.

-- In public (not app) so the check also evaluates for direct client
-- updates: authenticated has no usage on schema app.
create function public.has_course_identifier(p_text text) returns boolean
language sql immutable set search_path = pg_catalog, pg_temp as $$
  select coalesce(p_text, '') ~* '[a-z]{3}[ _-]?[0-9]{4}[a-z]?'
      or coalesce(p_text, '') ~ '[0-9]{4,}';
$$;
grant execute on function public.has_course_identifier(text)
  to anon, authenticated, service_role;

-- Existing names that break the rule become "Section A", "Section B", ...
-- per owner, oldest first. Members, sessions, and data are untouched.
with bad as (
  select id,
         row_number() over (partition by created_by order by created_at, id) as n
    from public.cohorts
   where public.has_course_identifier(name)
)
update public.cohorts c
   set name = 'Section ' || chr(64 + least(bad.n, 26)::int)
           || case when bad.n > 26 then ' ' || bad.n::text else '' end
  from bad
 where c.id = bad.id;

update public.live_sessions
   set title = 'Live session'
 where public.has_course_identifier(title);

alter table public.cohorts
  add constraint cohorts_name_no_course_id
  check (not public.has_course_identifier(name));

alter table public.live_sessions
  add constraint live_sessions_title_no_course_id
  check (not public.has_course_identifier(title));
