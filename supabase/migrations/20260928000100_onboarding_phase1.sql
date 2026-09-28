-- Onboarding phase 1: one console for faculty onboarding and student
-- browser identity (spec 2026-09-27, sections 1 and 2).
--
--   1. Faculty invites become links: expiry, revocation, a recipient hint,
--      and a signed-out preview for the #/welcome page. Staff can mint.
--   2. Faculty access requests: a professor without a link asks; staff
--      approve with one click.
--   3. my_console_role / my_student_classes: the console picks a home.
--   4. Live sessions: a signed-out preview, a member join that enrolls on
--      first use (same account as the iOS app), and guests opt-in.

-- ── 1. invite links ─────────────────────────────────────────────────────────
alter table public.faculty_invites
  add column expires_at timestamptz not null default now() + interval '14 days',
  add column recipient_email text
    check (recipient_email is null or length(recipient_email) <= 254),
  add column revoked_at timestamptz;

drop function public.mint_faculty_invite(text);
create function public.mint_faculty_invite(
  p_note text default null,
  p_recipient_email text default null
) returns text
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_code text;
begin
  if not (app.is_verified_faculty(auth.uid()) or app.is_admin(auth.uid())) then
    raise exception 'only verified faculty can mint invites';
  end if;
  insert into public.faculty_invites (minted_by, note, recipient_email)
  values (auth.uid(), nullif(trim(p_note), ''),
          nullif(lower(trim(p_recipient_email)), ''))
  returning code into v_code;
  return v_code;
end;
$$;
revoke all on function public.mint_faculty_invite(text, text) from public, anon;
grant execute on function public.mint_faculty_invite(text, text) to authenticated;

create function public.revoke_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  update public.faculty_invites
     set revoked_at = coalesce(revoked_at, now())
   where code = upper(trim(p_code))
     and (minted_by = auth.uid() or app.is_admin(auth.uid()));
  if not found then raise exception 'invite not found'; end if;
end;
$$;
revoke all on function public.revoke_faculty_invite(text) from public, anon;
grant execute on function public.revoke_faculty_invite(text) to authenticated;

-- Signed-out preview for the welcome page: validity and the inviter's
-- display name only. Nothing else about the invite leaves the server.
create function public.invite_preview(p_code text) returns jsonb
language sql stable security definer set search_path = public, app, pg_temp as $$
  select coalesce(
    (select jsonb_build_object(
              'valid', i.revoked_at is null and i.expires_at > now()
                       and i.uses < i.max_uses,
              'inviter', p.handle)
       from public.faculty_invites i
       join public.profiles p on p.id = i.minted_by
      where i.code = upper(trim(p_code))),
    jsonb_build_object('valid', false, 'inviter', null));
$$;
grant execute on function public.invite_preview(text) to anon, authenticated;

create or replace function public.redeem_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_row public.faculty_invites%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select * into v_row from public.faculty_invites
   where code = upper(trim(p_code)) for update;
  if not found or v_row.uses >= v_row.max_uses
     or v_row.revoked_at is not null or v_row.expires_at <= now() then
    raise exception 'invalid or exhausted invite code';
  end if;
  update public.faculty_invites set uses = uses + 1 where code = v_row.code;
  insert into app.verified_faculty (user_id, granted_by, note)
  values (v_user, v_row.minted_by, v_row.note)
  on conflict (user_id) do nothing;
end;
$$;

-- ── 2. faculty access requests ──────────────────────────────────────────────
create table public.faculty_access_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  school     text not null check (length(trim(school)) between 2 and 120),
  courses    text not null check (length(trim(courses)) between 2 and 200),
  note       text check (note is null or length(note) <= 500),
  status     text not null default 'pending'
             check (status in ('pending', 'approved', 'denied')),
  decided_by uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index faculty_access_requests_one_open
  on public.faculty_access_requests (user_id) where status = 'pending';
-- RPC-only: RLS on, no policies.
alter table public.faculty_access_requests enable row level security;

create function public.request_faculty_access(
  p_school text, p_courses text, p_note text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_row public.faculty_access_requests%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if app.is_verified_faculty(v_user) then
    raise exception 'already a verified instructor';
  end if;
  update public.faculty_access_requests
     set school = trim(p_school), courses = trim(p_courses),
         note = nullif(trim(p_note), '')
   where user_id = v_user and status = 'pending'
  returning * into v_row;
  if not found then
    insert into public.faculty_access_requests (user_id, school, courses, note)
    values (v_user, trim(p_school), trim(p_courses), nullif(trim(p_note), ''))
    returning * into v_row;
  end if;
  return jsonb_build_object('id', v_row.id, 'status', v_row.status,
    'school', v_row.school, 'courses', v_row.courses, 'note', v_row.note,
    'created_at', v_row.created_at);
end;
$$;
revoke all on function public.request_faculty_access(text, text, text) from public, anon;
grant execute on function public.request_faculty_access(text, text, text) to authenticated;

create function public.my_faculty_access_request() returns jsonb
language sql stable security definer set search_path = public, app, pg_temp as $$
  select jsonb_build_object('id', r.id, 'status', r.status, 'school', r.school,
           'courses', r.courses, 'note', r.note, 'created_at', r.created_at)
    from public.faculty_access_requests r
   where r.user_id = auth.uid()
   order by r.created_at desc
   limit 1;
$$;
revoke all on function public.my_faculty_access_request() from public, anon;
grant execute on function public.my_faculty_access_request() to authenticated;

create function public.admin_list_faculty_requests()
returns table (id uuid, user_id uuid, handle text, email text, school text,
               courses text, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select r.id, r.user_id, p.handle, u.email::text, r.school, r.courses,
           r.note, r.created_at
      from public.faculty_access_requests r
      join public.profiles p on p.id = r.user_id
      join auth.users u on u.id = r.user_id
     where r.status = 'pending'
     order by r.created_at;
end;
$$;
revoke all on function public.admin_list_faculty_requests() from public, anon;
grant execute on function public.admin_list_faculty_requests() to authenticated;

create function public.admin_decide_faculty_request(p_id uuid, p_approve boolean)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_user uuid;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  update public.faculty_access_requests
     set status = case when p_approve then 'approved' else 'denied' end,
         decided_by = auth.uid(), decided_at = now()
   where id = p_id and status = 'pending'
  returning user_id into v_user;
  if v_user is null then raise exception 'request not found or already decided'; end if;
  if p_approve then
    insert into app.verified_faculty (user_id, granted_by, note)
    values (v_user, auth.uid(), 'approved access request')
    on conflict (user_id) do nothing;
  end if;
end;
$$;
revoke all on function public.admin_decide_faculty_request(uuid, boolean) from public, anon;
grant execute on function public.admin_decide_faculty_request(uuid, boolean) to authenticated;

-- ── 3. console home ─────────────────────────────────────────────────────────
-- Highest role wins: staff, then faculty (verified or teaching a class as
-- faculty), then ta, then student, else none.
create function public.my_console_role() returns text
language sql stable security definer set search_path = public, app, pg_temp as $$
  select case
    when app.is_admin(auth.uid()) then 'staff'
    when app.is_verified_faculty(auth.uid())
      or exists (select 1 from public.cohort_members
                  where user_id = auth.uid() and role = 'faculty') then 'faculty'
    when exists (select 1 from public.cohort_members
                  where user_id = auth.uid() and role = 'ta') then 'ta'
    when exists (select 1 from public.cohort_members
                  where user_id = auth.uid() and role = 'student') then 'student'
    else 'none'
  end;
$$;
revoke all on function public.my_console_role() from public, anon;
grant execute on function public.my_console_role() to authenticated;

create function public.my_student_classes()
returns table (cohort_id uuid, name text, term text, professor text,
               roster_name text)
language sql stable security definer set search_path = public, app, pg_temp as $$
  select c.id, c.name, c.term, p.handle, m.roster_name
    from public.cohort_members m
    join public.cohorts c on c.id = m.cohort_id
    left join public.profiles p on p.id = c.created_by
   where m.user_id = auth.uid() and m.role = 'student'
   order by c.name;
$$;
revoke all on function public.my_student_classes() from public, anon;
grant execute on function public.my_student_classes() to authenticated;

-- ── 4. live sessions ────────────────────────────────────────────────────────
-- Guests become opt-in: class sessions admit signed-in students by default.
alter table public.live_sessions alter column allow_guests set default false;

drop function public.create_live_session(uuid, text, jsonb, int);
create function public.create_live_session(
  p_cohort uuid,
  p_title text,
  p_question_ids jsonb,
  p_question_seconds int default 20,
  p_allow_guests boolean default false
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_id uuid;
  v_code text;
  v_count int;
  v_valid int;
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  v_count := jsonb_array_length(p_question_ids);
  if v_count is null or v_count < 1 or v_count > 50 then
    raise exception 'a session needs 1 to 50 questions';
  end if;
  select count(*) into v_valid
    from jsonb_array_elements_text(p_question_ids) qid
    join public.questions q on q.id = qid::uuid
   where q.review_status = 'published'
     and (q.cohort_id is null or q.cohort_id = p_cohort);
  if v_valid <> v_count then
    raise exception 'question list contains unknown, unpublished, or foreign-cohort questions';
  end if;

  insert into public.live_sessions
    (cohort_id, created_by, title, question_ids, question_seconds, allow_guests)
  values
    (p_cohort, auth.uid(), trim(p_title), p_question_ids, p_question_seconds,
     coalesce(p_allow_guests, false))
  returning id, join_code into v_id, v_code;

  return jsonb_build_object('id', v_id, 'join_code', v_code,
                            'question_count', v_count);
end;
$$;
revoke all on function public.create_live_session(uuid, text, jsonb, int, boolean) from public, anon;
grant execute on function public.create_live_session(uuid, text, jsonb, int, boolean) to authenticated;

-- What a student sees before joining: the class and professor, plus their
-- own membership when signed in. No other member's data.
create function public.live_session_preview(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s record;
  m record;
begin
  select ls.id, ls.cohort_id, ls.title, ls.status, ls.allow_guests,
         c.name as class_name, p.handle as professor
    into s
    from public.live_sessions ls
    join public.cohorts c on c.id = ls.cohort_id
    left join public.profiles p on p.id = ls.created_by
   where ls.join_code = upper(trim(p_code)) and ls.status <> 'ended';
  if not found then raise exception 'invalid or ended session code'; end if;
  select cm.role, cm.roster_name into m
    from public.cohort_members cm
   where cm.cohort_id = s.cohort_id and cm.user_id = auth.uid();
  return jsonb_build_object(
    'title', s.title, 'status', s.status, 'allow_guests', s.allow_guests,
    'class_name', s.class_name, 'professor', s.professor,
    'is_member', m.role is not null, 'role', m.role,
    'roster_name', m.roster_name);
end;
$$;
grant execute on function public.live_session_preview(text) to anon, authenticated;

-- Signed-in (never anonymous) join that enrolls on first use. The same
-- email-code account the iOS app uses, so the professor sees one student.
create function public.join_live_session_as_student(
  p_code text, p_roster_name text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  s record;
  v_role text;
  v_name text := nullif(regexp_replace(trim(coalesce(p_roster_name, '')), '\s+', ' ', 'g'), '');
begin
  if v_user is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'sign in with your email to join as a student';
  end if;
  select * into s from public.live_sessions
   where join_code = upper(trim(p_code)) and status <> 'ended';
  if not found then raise exception 'invalid or ended session code'; end if;

  select role into v_role from public.cohort_members
   where cohort_id = s.cohort_id and user_id = v_user;
  if v_role in ('faculty', 'ta') then raise exception 'you teach this class'; end if;

  if v_role is null then
    if v_name is null or length(v_name) not between 2 and 60 then
      raise exception 'enter your name as your professor knows it (2 to 60 characters)';
    end if;
    -- First web sign-in may race the client's profile bootstrap.
    insert into public.profiles (id, handle)
    values (v_user, 'user_' || substr(replace(v_user::text, '-', ''), 1, 12))
    on conflict (id) do nothing;
    insert into public.cohort_members (cohort_id, user_id, role, roster_name)
    values (s.cohort_id, v_user, 'student', v_name);
  end if;

  insert into public.live_participants (session_id, user_id)
  values (s.id, v_user)
  on conflict do nothing;

  return jsonb_build_object(
    'id', s.id, 'title', s.title, 'status', s.status,
    'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds);
end;
$$;
revoke all on function public.join_live_session_as_student(text, text) from public, anon;
grant execute on function public.join_live_session_as_student(text, text) to authenticated;
