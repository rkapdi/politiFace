# Onboarding Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A professor can go from an invite link (or an access request) to a created class entirely inside `politiface.app/app`, and a student can join a live session in any browser with the same email-code account the iOS app uses, enrolling in the class on first join.

**Architecture:** One Postgres migration adds invite-link fields, faculty access requests, a console-role resolver, a public session preview, and a member join that enrolls. The React console gains a reusable email-code form, a role-based home (faculty console, student home, or request access), a public `#/welcome` invite route with a three-step setup, and a rewritten `#/join` route. Guests become opt-in per session.

**Tech Stack:** Supabase Postgres (plpgsql security-definer RPCs, RLS), React 19 + TanStack Router (hash history) + TanStack Query, Vitest + Testing Library, plain-Postgres smoke tests (`supabase/tests/run_local.sh`).

**Spec:** `docs/superpowers/specs/2026-09-27-onboarding-and-admin-console-design.md` (Sections 1 and 2; phase 1 of the phasing). Phases 2 (admin console) and 3 (impersonation, `/faculty` retirement) get their own plans.

## Global Constraints

- No em-dashes in any UI copy, SQL comment shown to users, or doc (house rule).
- All user-facing strings live in `web/src/lib/strings.ts` (`S`); server error text is mapped to friendly copy in `FRIENDLY` in `web/src/lib/api.ts`.
- Every RPC is `security definer set search_path = public, app, pg_temp` and checks the caller itself; the UI is only a view.
- Never collect political affiliation or voting history. Collect only: email (auth), roster name the student types (2 to 60 chars), school and courses text for faculty requests.
- Positioning copy: "supplemental practice students choose", never "official prep".
- `web/src/lib/database.types.ts` is generated from the hosted schema. New RPC entries are added by hand in generator format (Task 4) only until the founder applies the migration; then it is regenerated (Task 11) and must match.
- Migrations are applied to production by the founder (the agent's production writes are blocked). Everything must pass `./supabase/tests/run_local.sh` locally first.
- Deferred from the spec to phase 2: the printable class QR poster at the end of the setup wizard (phase 1 ends on the class page, which already shows the join code), the audit log, and the full admin console. Phase 1 puts a minimal "Invite an instructor" + "Instructor requests" card on the classes page so onboarding works this week.

## File map

- Create `supabase/migrations/20260928000100_onboarding_phase1.sql`: all phase 1 schema and RPCs (built up across Tasks 1 to 3).
- Modify `supabase/tests/shim_auth.sql`: add an `auth.jwt()` stand-in.
- Modify `supabase/tests/smoke.sql`: new phase 1 block; the existing guest test opts into guests.
- Modify `web/src/lib/database.types.ts`: new RPC entries (Task 4), regenerated in Task 11.
- Modify `web/src/lib/api.ts`: fetchers, hooks, error mappings.
- Modify `web/src/lib/strings.ts`: onboarding, join, student, request-access copy.
- Create `web/src/auth/EmailCodeForm.tsx`: the email then 6-digit-code form, reused by sign-in, welcome, and join.
- Modify `web/src/auth/SignIn.tsx`: thin wrapper over `EmailCodeForm`.
- Create `web/src/routes/HomePage.tsx`: picks the home by console role.
- Create `web/src/components/StudentHome.tsx`, `web/src/components/RequestAccess.tsx`, `web/src/components/StaffTools.tsx`.
- Modify `web/src/routes/ClassesPage.tsx`: export `CreateClassCard`, render `StaffTools`.
- Create `web/src/routes/WelcomePage.tsx`: invite landing + setup wizard.
- Rewrite `web/src/routes/JoinPage.tsx`: preview, sign-in, member and first-time joins, optional guest path.
- Modify `web/src/routes/router.tsx`: `#/welcome` public route, home route uses `HomePage`.
- Modify `web/src/components/LiveTab.tsx`, `web/src/components/QuestionPicker.tsx`: allow-guests toggle.
- Tests: `web/src/auth/emailCodeForm.test.tsx`, `web/src/routes/HomePage.test.tsx`, `web/src/components/staffTools.test.tsx`, `web/src/routes/WelcomePage.test.tsx`, `web/src/routes/JoinPage.test.tsx` (rewritten), `web/src/components/questionPicker.test.tsx`.

---

### Task 1: Invite links (schema, RPCs, smoke)

**Files:**
- Modify: `supabase/tests/shim_auth.sql` (append)
- Create: `supabase/migrations/20260928000100_onboarding_phase1.sql`
- Modify: `supabase/tests/smoke.sql` (insert before the final `reset role; select 'SMOKE TEST PASSED'`)

**Interfaces:**
- Produces (SQL):
  - `public.mint_faculty_invite(p_note text default null, p_recipient_email text default null) returns text` (verified faculty or staff)
  - `public.revoke_faculty_invite(p_code text) returns void` (minter or staff)
  - `public.invite_preview(p_code text) returns jsonb` `{ valid: boolean, inviter: text|null }` (anon allowed)
  - `public.redeem_faculty_invite(p_code text) returns void` now refuses expired or revoked codes with `invalid or exhausted invite code`
  - `auth.jwt()` in the test shim reads `app.test_jwt`

- [ ] **Step 1: Add the `auth.jwt()` shim**

Append to `supabase/tests/shim_auth.sql`:

```sql
-- Test stand-in for Supabase's auth.jwt(): the claims of the current JWT.
-- Tests set app.test_jwt to a JSON object (for example '{"is_anonymous": true}').
create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('app.test_jwt', true), ''), '{}')::jsonb;
$$;
grant execute on function auth.jwt() to anon, authenticated, service_role;
```

- [ ] **Step 2: Write the failing smoke block**

In `supabase/tests/smoke.sql`, immediately before the final lines `reset role;` / `select 'SMOKE TEST PASSED' as result;`, insert:

```sql
-- ── Onboarding phase 1 (20260928000100) ────────────────────────────────────
\set p1_prof    '''00000000-0000-0000-0000-0000000000a1'''
\set p1_asker   '''00000000-0000-0000-0000-0000000000a2'''
\set p1_student '''00000000-0000-0000-0000-0000000000a3'''
\set p1_anon    '''00000000-0000-0000-0000-0000000000a4'''
reset role;
insert into auth.users (id, email) values
  (:p1_prof, 'newprof@example.edu'),
  (:p1_asker, 'asker@example.edu'),
  (:p1_student, 'webstudent@example.edu'),
  (:p1_anon, null);
set role authenticated;

-- Invites: faculty mint with a recipient hint; one revoked, one expired.
set app.test_uid = :f_uid;
do $$
begin
  perform set_config('app.p1_invite',
    public.mint_faculty_invite('For Prof. New', 'newprof@example.edu'), false);
  perform set_config('app.p1_dead', public.mint_faculty_invite('to revoke'), false);
  perform public.revoke_faculty_invite(current_setting('app.p1_dead'));
  perform set_config('app.p1_expired', public.mint_faculty_invite('smoke expiry'), false);
end $$;
reset role;
update public.faculty_invites set expires_at = now() - interval '1 minute'
 where code = current_setting('app.p1_expired');

-- Preview works signed out and never calls a dead code valid.
set role anon;
set app.test_uid = '';
do $$
declare p jsonb;
begin
  p := public.invite_preview(current_setting('app.p1_invite'));
  if not (p ->> 'valid')::boolean or p ->> 'inviter' is null then
    raise exception 'FAIL: live invite preview wrong: %', p;
  end if;
  if (public.invite_preview(current_setting('app.p1_dead')) ->> 'valid')::boolean then
    raise exception 'FAIL: revoked invite previewed as valid';
  end if;
  if (public.invite_preview(current_setting('app.p1_expired')) ->> 'valid')::boolean then
    raise exception 'FAIL: expired invite previewed as valid';
  end if;
  if (public.invite_preview('NOPE00') ->> 'valid')::boolean then
    raise exception 'FAIL: unknown invite previewed as valid';
  end if;
end $$;
set role authenticated;

-- Revoked and expired codes refuse; the live one verifies.
set app.test_uid = :p1_prof;
insert into public.profiles (id, handle) values (:p1_prof, 'new_prof');
do $$
begin
  begin
    perform public.redeem_faculty_invite(current_setting('app.p1_dead'));
    raise exception 'FAIL: revoked invite redeemed';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.redeem_faculty_invite(current_setting('app.p1_expired'));
    raise exception 'FAIL: expired invite redeemed';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  perform public.redeem_faculty_invite(current_setting('app.p1_invite'));
  if not public.am_verified_faculty() then
    raise exception 'FAIL: live invite did not verify the professor';
  end if;
end $$;

-- A student cannot revoke someone else's invite.
set app.test_uid = :s2_uid;
do $$
begin
  begin
    perform public.revoke_faculty_invite(current_setting('app.p1_invite'));
    raise exception 'FAIL: student revoked an invite';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
```

- [ ] **Step 3: Run the smoke test to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.revoke_faculty_invite(text) does not exist` (or `mint_faculty_invite` arity error).

- [ ] **Step 4: Write the invite part of the migration**

Create `supabase/migrations/20260928000100_onboarding_phase1.sql`:

```sql
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
```

- [ ] **Step 5: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: the phase 1 invite block passes; the run then reaches `SMOKE TEST PASSED` / `OK: migrations + smoke test passed`.

- [ ] **Step 6: Commit**

```bash
git add supabase/tests/shim_auth.sql supabase/tests/smoke.sql supabase/migrations/20260928000100_onboarding_phase1.sql
git commit -m "Onboarding: invite links with expiry, revocation, and signed-out preview"
```

---

### Task 2: Faculty access requests and console role (schema, RPCs, smoke)

**Files:**
- Modify: `supabase/migrations/20260928000100_onboarding_phase1.sql` (append)
- Modify: `supabase/tests/smoke.sql` (append to the phase 1 block)

**Interfaces:**
- Consumes: Task 1 identities and `app.p1_*` settings.
- Produces (SQL):
  - `public.request_faculty_access(p_school text, p_courses text, p_note text default null) returns jsonb` (the request row as JSON; updates the caller's open request instead of adding a second; refuses verified faculty with `already a verified instructor`)
  - `public.my_faculty_access_request() returns jsonb` (latest request `{id, status, school, courses, note, created_at}` or JSON null)
  - `public.admin_list_faculty_requests() returns table (id uuid, user_id uuid, handle text, email text, school text, courses text, note text, created_at timestamptz)` (staff; pending only, oldest first)
  - `public.admin_decide_faculty_request(p_id uuid, p_approve boolean) returns void` (staff)
  - `public.my_console_role() returns text`: one of `staff`, `faculty`, `ta`, `student`, `none`
  - `public.my_student_classes() returns table (cohort_id uuid, name text, term text, professor text, roster_name text)`

- [ ] **Step 1: Write the failing smoke block**

Append to the phase 1 block in `supabase/tests/smoke.sql` (still before the final `SMOKE TEST PASSED` lines):

```sql
-- Access requests: an unknown user asks, can revise, cannot self-approve.
set app.test_uid = :p1_asker;
insert into public.profiles (id, handle) values (:p1_asker, 'asker');
do $$
declare r jsonb;
begin
  if public.my_console_role() <> 'none' then
    raise exception 'FAIL: fresh user console role %', public.my_console_role();
  end if;
  r := public.request_faculty_access('MDC North', 'POS 2041', 'Three sections');
  if r ->> 'status' <> 'pending' then raise exception 'FAIL: request not pending'; end if;
  r := public.request_faculty_access('MDC North', 'POS 2041, INR 2002', null);
  if public.my_faculty_access_request() ->> 'courses' <> 'POS 2041, INR 2002' then
    raise exception 'FAIL: resubmitting did not update the open request';
  end if;
  perform set_config('app.p1_request', r ->> 'id', false);
  begin
    perform * from public.admin_list_faculty_requests();
    raise exception 'FAIL: non-staff listed faculty requests';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.admin_decide_faculty_request(
      current_setting('app.p1_request')::uuid, true);
    raise exception 'FAIL: requester approved their own request';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Staff (f_uid is an admin earlier in this file) sees it and approves.
set app.test_uid = :f_uid;
do $$
begin
  if public.my_console_role() <> 'staff' then
    raise exception 'FAIL: admin console role %', public.my_console_role();
  end if;
  if not exists (select 1 from public.admin_list_faculty_requests()
                  where id = current_setting('app.p1_request')::uuid
                    and email = 'asker@example.edu') then
    raise exception 'FAIL: pending request missing from the staff list';
  end if;
  perform public.admin_decide_faculty_request(
    current_setting('app.p1_request')::uuid, true);
end $$;

set app.test_uid = :p1_asker;
do $$
begin
  if public.my_faculty_access_request() ->> 'status' <> 'approved' then
    raise exception 'FAIL: request not approved';
  end if;
  if public.my_console_role() <> 'faculty' then
    raise exception 'FAIL: approved requester console role %', public.my_console_role();
  end if;
  begin
    perform public.request_faculty_access('MDC North', 'POS 2041', null);
    raise exception 'FAIL: verified instructor filed a request';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- A class member with no teaching role gets the student home.
set app.test_uid = :s1_uid;
do $$
begin
  if public.my_console_role() <> 'student' then
    raise exception 'FAIL: student console role %', public.my_console_role();
  end if;
  if not exists (select 1 from public.my_student_classes()
                  where name = 'POS2041 Fall') then
    raise exception 'FAIL: my_student_classes missing the joined class';
  end if;
end $$;
```

- [ ] **Step 2: Run to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.my_console_role() does not exist`.

- [ ] **Step 3: Append the access-request and console-role SQL**

Append to `supabase/migrations/20260928000100_onboarding_phase1.sql`:

```sql
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
language plpgsql stable security definer set search_path = public, app, auth, pg_temp as $$
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
```

- [ ] **Step 4: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -3`
Expected: `OK: migrations + smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add supabase/tests/smoke.sql supabase/migrations/20260928000100_onboarding_phase1.sql
git commit -m "Onboarding: faculty access requests and console role resolver"
```

---

### Task 3: Live session preview, enrolling member join, guests opt-in (schema, RPCs, smoke)

**Files:**
- Modify: `supabase/migrations/20260928000100_onboarding_phase1.sql` (append)
- Modify: `supabase/tests/smoke.sql` (existing guest test + phase 1 block)

**Interfaces:**
- Consumes: Task 1 identities.
- Produces (SQL):
  - `public.live_session_preview(p_code text) returns jsonb` `{ title, status, allow_guests, class_name, professor, is_member, role, roster_name }`; raises `invalid or ended session code` (anon allowed)
  - `public.join_live_session_as_student(p_code text, p_roster_name text default null) returns jsonb` (same shape as `join_live_session`: `{id, title, status, index, total, question_seconds}`); errors: `sign in with your email to join as a student`, `you teach this class`, `enter your name as your professor knows it (2 to 60 characters)`, `invalid or ended session code`
  - `public.create_live_session(p_cohort uuid, p_title text, p_question_ids jsonb, p_question_seconds int default 20, p_allow_guests boolean default false) returns jsonb`
  - `live_sessions.allow_guests` default `false`

- [ ] **Step 1: Keep the existing guest test explicit about guests**

In `supabase/tests/smoke.sql`, find the `create_live_session` call inside the guest-join block (it creates `'Guest-joinable quiz'`) and change its last argument from `20);` to `20, true);`:

```sql
  v_session := public.create_live_session(
    v_cohort, 'Guest-joinable quiz',
    (select jsonb_agg(id) from (select id from public.questions
       where cohort_id is null and review_status = 'published'
       limit 2) q), 20, true);
```

- [ ] **Step 2: Write the failing phase 1 live block**

Append to the phase 1 block in `supabase/tests/smoke.sql`:

```sql
-- Live: new sessions default to no guests.
set app.test_uid = :f_uid;
do $$
declare v jsonb;
begin
  v := public.create_live_session(
    (select id from public.cohorts where name = 'POS2041 Fall'),
    'Members only quiz',
    (select jsonb_agg(id) from (select id from public.questions
       where cohort_id is null and review_status = 'published' limit 2) q),
    20);
  perform set_config('app.p1_code', v ->> 'join_code', false);
  perform set_config('app.p1_session', v ->> 'id', false);
  if (select allow_guests from public.live_sessions where id = (v ->> 'id')::uuid) then
    raise exception 'FAIL: new sessions must default to no guests';
  end if;
  begin
    perform public.join_live_session_as_student(v ->> 'join_code', 'Prof');
    raise exception 'FAIL: faculty joined their own session as a student';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Signed out: preview shows the class, never member data.
set role anon;
set app.test_uid = '';
do $$
declare p jsonb;
begin
  p := public.live_session_preview(current_setting('app.p1_code'));
  if p ->> 'class_name' <> 'POS2041 Fall' or (p ->> 'allow_guests')::boolean
     or (p ->> 'is_member')::boolean or p ->> 'roster_name' is not null then
    raise exception 'FAIL: signed-out preview wrong: %', p;
  end if;
  begin
    perform public.live_session_preview('ZZZZZZ');
    raise exception 'FAIL: preview of an unknown code succeeded';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
set role authenticated;

-- Anonymous sessions can neither guest-join a no-guest session nor join as
-- a student.
set app.test_uid = :p1_anon;
set app.test_jwt = '{"is_anonymous": true}';
do $$
begin
  begin
    perform public.join_live_session_guest(current_setting('app.p1_code'), 'Guest Person');
    raise exception 'FAIL: guest joined a no-guest session';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.join_live_session_as_student(current_setting('app.p1_code'), 'Guest Person');
    raise exception 'FAIL: anonymous user joined as a student';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
set app.test_jwt = '';

-- A signed-in web student with no profile yet: first join enrolls with a
-- roster name; later joins reuse it.
set app.test_uid = :p1_student;
do $$
declare v jsonb;
begin
  begin
    perform public.join_live_session_as_student(current_setting('app.p1_code'), 'x');
    raise exception 'FAIL: one-character roster name accepted';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  v := public.join_live_session_as_student(current_setting('app.p1_code'), '  Maria   Lopez ');
  if (v ->> 'id')::uuid <> current_setting('app.p1_session')::uuid then
    raise exception 'FAIL: student join returned the wrong session';
  end if;
  if public.my_console_role() <> 'student' then
    raise exception 'FAIL: web student console role %', public.my_console_role();
  end if;
  if public.live_session_preview(current_setting('app.p1_code')) ->> 'roster_name'
     <> 'Maria Lopez' then
    raise exception 'FAIL: roster name not stored normalized';
  end if;
  v := public.join_live_session_as_student(current_setting('app.p1_code'), null);
  if not (public.live_session_preview(current_setting('app.p1_code')) ->> 'is_member')::boolean then
    raise exception 'FAIL: rejoin lost membership';
  end if;
end $$;
```

- [ ] **Step 3: Run to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.create_live_session(uuid, unknown, jsonb, integer, boolean) does not exist` at the guest test.

- [ ] **Step 4: Confirm the production body of `create_live_session` matches the repo**

Run (read-only):
```bash
supabase db query --linked "select pg_get_functiondef('public.create_live_session(uuid,text,jsonb,integer)'::regprocedure) d" -o json
```
Expected: the body matches `supabase/migrations/20260821000100_roles_ta_org_admins.sql` (`app.is_cohort_ta_or_above` gate, 1 to 50 questions, published and same-cohort check). If it differs, carry the production body forward in Step 5 instead and note the difference in the commit message.

- [ ] **Step 5: Append the live SQL**

Append to `supabase/migrations/20260928000100_onboarding_phase1.sql`:

```sql
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
```

- [ ] **Step 6: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -3`
Expected: `OK: migrations + smoke test passed`.

- [ ] **Step 7: Commit**

```bash
git add supabase/tests/smoke.sql supabase/migrations/20260928000100_onboarding_phase1.sql
git commit -m "Onboarding: session preview, enrolling student join, guests opt-in"
```

---

### Task 4: Web API layer, types, strings

**Files:**
- Modify: `web/src/lib/database.types.ts` (inside `public` → `Functions`, keep alphabetical order)
- Modify: `web/src/lib/api.ts`
- Modify: `web/src/lib/strings.ts`
- Test: `web/src/lib/api.test.ts` (append)

**Interfaces:**
- Consumes: Task 1 to 3 RPC names and shapes.
- Produces (TypeScript, all exported from `web/src/lib/api.ts`):
  - `type ConsoleRole = 'staff' | 'faculty' | 'ta' | 'student' | 'none'`
  - `useMyConsoleRole(enabled?: boolean)` query key `['console-role']`
  - `type InvitePreview = { valid: boolean; inviter: string | null }`, `invitePreview(code: string): Promise<InvitePreview>`
  - `redeemFacultyInvite(code: string): Promise<void>`
  - `useMintFacultyInvite()` mutation `{ note?: string; recipientEmail?: string } -> string` (code)
  - `inviteLink(code: string): string` → `${location.origin}${location.pathname}#/welcome?invite=${code}`
  - `type AccessRequest = { id: string; status: 'pending' | 'approved' | 'denied'; school: string; courses: string; note: string | null; created_at: string }`
  - `useMyAccessRequest()` (refetches every 15 s while pending), `useRequestFacultyAccess()`
  - `type PendingRequest = { id: string; user_id: string; handle: string; email: string; school: string; courses: string; note: string | null; created_at: string }`
  - `useFacultyRequests(enabled: boolean)`, `useDecideFacultyRequest()`
  - `type StudentClass = { cohort_id: string; name: string; term: string | null; professor: string | null; roster_name: string | null }`, `useMyStudentClasses()`
  - `useJoinClass()` mutation `{ code: string; rosterName: string } -> string` (cohort id) via `join_cohort`
  - `type SessionPreview = { title: string; status: LiveJoin['status']; allow_guests: boolean; class_name: string; professor: string | null; is_member: boolean; role: 'student' | 'faculty' | 'ta' | null; roster_name: string | null }`, `liveSessionPreview(code: string): Promise<SessionPreview>`
  - `joinLiveSession(code: string): Promise<LiveJoin>`, `joinLiveSessionAsStudent(code: string, rosterName: string | null): Promise<LiveJoin>`
  - `useCreateLiveSession()` args gain `allowGuests: boolean`

- [ ] **Step 1: Add the generated-format type entries**

In `web/src/lib/database.types.ts`, inside `public: { ... Functions: { ... } }`, add or update these entries at their alphabetical positions (replace the existing `create_live_session` and `mint_faculty_invite` entries):

```ts
      admin_decide_faculty_request: {
        Args: { p_approve: boolean; p_id: string }
        Returns: undefined
      }
      admin_list_faculty_requests: {
        Args: never
        Returns: {
          courses: string
          created_at: string
          email: string
          handle: string
          id: string
          note: string
          school: string
          user_id: string
        }[]
      }
      create_live_session: {
        Args: {
          p_allow_guests?: boolean
          p_cohort: string
          p_question_ids: Json
          p_question_seconds?: number
          p_title: string
        }
        Returns: Json
      }
      invite_preview: { Args: { p_code: string }; Returns: Json }
      join_live_session_as_student: {
        Args: { p_code: string; p_roster_name?: string }
        Returns: Json
      }
      live_session_preview: { Args: { p_code: string }; Returns: Json }
      mint_faculty_invite: {
        Args: { p_note?: string; p_recipient_email?: string }
        Returns: string
      }
      my_console_role: { Args: never; Returns: string }
      my_faculty_access_request: { Args: never; Returns: Json }
      my_student_classes: {
        Args: never
        Returns: {
          cohort_id: string
          name: string
          professor: string
          roster_name: string
          term: string
        }[]
      }
      request_faculty_access: {
        Args: { p_courses: string; p_note?: string; p_school: string }
        Returns: Json
      }
      revoke_faculty_invite: { Args: { p_code: string }; Returns: undefined }
```

Before adding, check how the file spells no-argument functions (search for `my_cohort_role` or `am_admin` and copy its `Args` form exactly, `never` or `Record<PropertyKey, never>`), and use that form for every `Args: never` above.

- [ ] **Step 2: Write the failing API test**

Append to `web/src/lib/api.test.ts`:

```ts
import { inviteLink } from './api'

describe('inviteLink', () => {
  it('builds a hash-route welcome link on the current console URL', () => {
    expect(inviteLink('D7QMJA')).toBe(
      `${window.location.origin}${window.location.pathname}#/welcome?invite=D7QMJA`,
    )
  })
})
```

If `describe`/`it`/`expect` are not already imported at the top of that file, add `import { describe, expect, it } from 'vitest'`.

- [ ] **Step 3: Run it to verify it fails**

Run: `cd web && npx vitest run src/lib/api.test.ts`
Expected: FAIL, `inviteLink` is not exported.

- [ ] **Step 4: Add strings**

In `web/src/lib/strings.ts`, replace the `needsVerification` entry and add entries inside `errors`, then add the new top-level groups before `provenance`:

```ts
    needsVerification:
      'Creating classes requires instructor access. Use your invite link, or request access from the home page.',
    badInvite:
      'That invite link has expired or was already used. Ask the person who invited you for a new one.',
    alreadyFaculty: 'You are already a verified instructor.',
    rosterName: 'Enter your name as your professor knows it (2 to 60 characters).',
    badClassCode: 'That class code does not match a class. Check it with your professor.',
    signInToJoin: 'Sign in with your email to join as a student.',
    youTeach: 'You teach this class. Run the session from your console instead.',
```

```ts
  signIn: {
    title: 'Sign in to Politiface',
    intro: 'We email you a 6-digit code; there is no password.',
    email: 'Email',
    sendCode: 'Send code',
    sentTo: 'We emailed a 6-digit code to',
    code: 'Code',
    submit: 'Sign in',
    differentEmail: 'Use a different email',
    sendFailed: 'We could not send a code to that address. Check the email and try again.',
    badCode: 'That code did not match. Codes expire quickly; request a new one if needed.',
    schoolEmailHint: 'Use your school email. It is the same account as the Politiface app.',
  },
  welcome: {
    title: 'You are invited to Politiface as an instructor',
    invitedBy: 'Invited by',
    invalid:
      'This invite link has expired or was already used. Ask the person who invited you for a new one.',
    verifying: 'Setting up your instructor access',
    stepProfile: 'Your profile',
    stepClass: 'Your first class',
    profileHint: 'Your display name is shown to co-faculty and on class announcements.',
    classHint: 'Students join with a code you get on the next screen. You can add more classes later.',
    next: 'Next',
    createClass: 'Create class',
    className: 'Class name',
    classNamePlaceholder: 'POS 2041, section 67',
    term: 'Term, optional',
  },
  requestAccess: {
    title: 'Are you an instructor?',
    intro:
      'Request instructor access to create classes and run live sessions. If a colleague sent you an invite link, open that link instead.',
    school: 'School',
    courses: 'Courses you teach',
    coursesPlaceholder: 'POS 2041, INR 2002',
    note: 'Anything we should know (optional)',
    submit: 'Request access',
    pending: 'Request sent. You can create classes as soon as it is approved; this page updates on its own.',
    denied: 'Your request was not approved. Reply to your invite or contact support@politiface.app.',
    studentInstead: 'Are you a student? Join a live session with the code your professor shows.',
  },
  student: {
    title: 'Your classes',
    none: 'You have not joined a class yet.',
    joinSession: 'Join a live session',
    sessionCode: 'Session code',
    join: 'Join',
    joinClass: 'Join a class',
    classCode: 'Class code',
    rosterName: 'Your name as your professor knows it',
    joined: 'You joined the class.',
    getApp: 'Practice between sessions with the Politiface app, supplemental practice you choose.',
  },
  join: {
    title: 'Join a live session',
    with: 'with',
    signInIntro: 'Sign in to join. Use your school email; it is the same account as the Politiface app.',
    joinAs: 'Join as',
    firstTimeName: 'Your name as your professor knows it',
    joinClass: 'Join',
    notYou: 'Not you? Sign out',
    guest: 'Join without signing in',
    guestNote: 'Guest answers count for this session only and are not added to your class record.',
    guestName: 'Your name',
  },
  staffTools: {
    inviteTitle: 'Invite an instructor',
    inviteHint: 'Creates a single-use link that verifies them and walks them into their first class. Links expire in 14 days.',
    recipient: 'Their email (optional, for your records)',
    note: 'Note (optional)',
    mint: 'Create invite link',
    copy: 'Copy link',
    copied: 'Copied',
    requestsTitle: 'Instructor requests',
    noRequests: 'No pending requests.',
    approve: 'Approve',
    deny: 'Deny',
  },
```

- [ ] **Step 5: Add fetchers, hooks, and error mappings**

In `web/src/lib/api.ts`:

(a) Add to `FRIENDLY`:

```ts
  'invalid or exhausted invite code': S.errors.badInvite,
  'already a verified instructor': S.errors.alreadyFaculty,
  'enter your name as your professor knows it (2 to 60 characters)':
    S.errors.rosterName,
  'invalid join code': S.errors.badClassCode,
  'sign in with your email to join as a student': S.errors.signInToJoin,
  'you teach this class': S.errors.youTeach,
  'join the class first': S.errors.membersOnly,
```

(b) After `signInAnonymously`, add the fetchers:

```ts
export type ConsoleRole = 'staff' | 'faculty' | 'ta' | 'student' | 'none'
export const myConsoleRole = () => rpc<ConsoleRole>('my_console_role')

export type InvitePreview = { valid: boolean; inviter: string | null }
export const invitePreview = (code: string) =>
  rpc<InvitePreview>('invite_preview', { p_code: code })
export const redeemFacultyInvite = async (code: string): Promise<void> => {
  await rpc('redeem_faculty_invite', { p_code: code })
}
export const inviteLink = (code: string) =>
  `${window.location.origin}${window.location.pathname}#/welcome?invite=${code}`

export type AccessRequest = {
  id: string
  status: 'pending' | 'approved' | 'denied'
  school: string
  courses: string
  note: string | null
  created_at: string
}
export type PendingRequest = {
  id: string
  user_id: string
  handle: string
  email: string
  school: string
  courses: string
  note: string | null
  created_at: string
}
export type StudentClass = {
  cohort_id: string
  name: string
  term: string | null
  professor: string | null
  roster_name: string | null
}
export type SessionPreview = {
  title: string
  status: LiveJoin['status']
  allow_guests: boolean
  class_name: string
  professor: string | null
  is_member: boolean
  role: 'student' | 'faculty' | 'ta' | null
  roster_name: string | null
}
export const liveSessionPreview = (code: string) =>
  rpc<SessionPreview>('live_session_preview', { p_code: code })
export const joinLiveSession = (code: string) =>
  rpc<LiveJoin>('join_live_session', { p_code: code })
export const joinLiveSessionAsStudent = (code: string, rosterName: string | null) =>
  rpc<LiveJoin>('join_live_session_as_student', {
    p_code: code,
    ...(rosterName ? { p_roster_name: rosterName } : {}),
  })
```

(c) In the query-hooks section, add:

```ts
export const useMyConsoleRole = (enabled = true) =>
  useQuery({ queryKey: ['console-role'], queryFn: myConsoleRole, enabled })
export const useMyAccessRequest = () =>
  useQuery({
    queryKey: ['access-request'],
    queryFn: () => rpc<AccessRequest | null>('my_faculty_access_request'),
    refetchInterval: q =>
      q.state.data?.status === 'pending' ? 15_000 : false,
  })
export const useFacultyRequests = (enabled: boolean) =>
  useQuery({
    queryKey: ['admin', 'faculty-requests'],
    queryFn: () => rpc<PendingRequest[]>('admin_list_faculty_requests'),
    enabled,
  })
export const useMyStudentClasses = () =>
  useQuery({
    queryKey: ['student-classes'],
    queryFn: () => rpc<StudentClass[]>('my_student_classes'),
  })
```

(d) In the mutations section, add:

```ts
export const useRequestFacultyAccess = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { school: string; courses: string; note: string }) =>
      rpc<AccessRequest>('request_faculty_access', {
        p_school: a.school,
        p_courses: a.courses,
        ...(a.note ? { p_note: a.note } : {}),
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['access-request'] }),
  })
}

export const useDecideFacultyRequest = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { id: string; approve: boolean }) =>
      rpc('admin_decide_faculty_request', { p_id: a.id, p_approve: a.approve }),
    onSuccess: () =>
      void qc.invalidateQueries({ queryKey: ['admin', 'faculty-requests'] }),
  })
}

export const useMintFacultyInvite = () =>
  useMutation({
    mutationFn: (a: { note?: string; recipientEmail?: string }) =>
      rpc<string>('mint_faculty_invite', {
        ...(a.note ? { p_note: a.note } : {}),
        ...(a.recipientEmail ? { p_recipient_email: a.recipientEmail } : {}),
      }),
  })

export const useJoinClass = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { code: string; rosterName: string }) =>
      rpc<string>('join_cohort', {
        p_code: a.code,
        p_roster_name: a.rosterName,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['student-classes'] })
      void qc.invalidateQueries({ queryKey: ['console-role'] })
    },
  })
}
```

(e) In `useCreateLiveSession`, add `allowGuests: boolean` to the args type and `p_allow_guests: a.allowGuests,` to the RPC args.

- [ ] **Step 6: Run the tests and typecheck**

Run: `cd web && npx vitest run src/lib/api.test.ts && npm run typecheck`
Expected: PASS. Typecheck reports one error in `QuestionPicker.tsx` (missing `allowGuests`); Task 10 fixes it. If any other file errors, fix it here.

- [ ] **Step 7: Commit**

```bash
git add web/src/lib/database.types.ts web/src/lib/api.ts web/src/lib/api.test.ts web/src/lib/strings.ts
git commit -m "Onboarding: web API layer, types, and copy"
```

---

### Task 5: Reusable email-code form

**Files:**
- Create: `web/src/auth/EmailCodeForm.tsx`
- Modify: `web/src/auth/SignIn.tsx`
- Test: `web/src/auth/emailCodeForm.test.tsx`

**Interfaces:**
- Produces: `EmailCodeForm({ hint }: { hint?: string })`. Renders the email step then the code step; calls `supabase.auth.signInWithOtp({ email })` and `supabase.auth.verifyOtp({ email, token, type: 'email' })`. On success it renders nothing more; the `SessionProvider` session change moves the parent on.

- [ ] **Step 1: Write the failing test**

Create `web/src/auth/emailCodeForm.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const { signInWithOtp, verifyOtp } = vi.hoisted(() => ({
  signInWithOtp: vi.fn(async () => ({ error: null })),
  verifyOtp: vi.fn(async () => ({ error: null })),
}))
vi.mock('../lib/supabase', () => ({
  supabase: { auth: { signInWithOtp, verifyOtp } },
}))

import { EmailCodeForm } from './EmailCodeForm'

describe('EmailCodeForm', () => {
  it('sends a code, then verifies it for the same trimmed email', async () => {
    render(<EmailCodeForm hint="Use your school email." />)
    expect(screen.getByText('Use your school email.')).toBeInTheDocument()
    await userEvent.type(screen.getByLabelText(/email/i), ' maria@mymdc.net ')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    expect(signInWithOtp).toHaveBeenCalledWith({ email: 'maria@mymdc.net' })
    await userEvent.type(await screen.findByLabelText(/^code$/i), '123456')
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    expect(verifyOtp).toHaveBeenCalledWith({
      email: 'maria@mymdc.net',
      token: '123456',
      type: 'email',
    })
  })

  it('shows an error when the code does not match', async () => {
    verifyOtp.mockResolvedValueOnce({ error: { message: 'bad' } } as never)
    render(<EmailCodeForm />)
    await userEvent.type(screen.getByLabelText(/email/i), 'a@b.co')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    await userEvent.type(await screen.findByLabelText(/^code$/i), '000000')
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    expect(await screen.findByRole('alert')).toHaveTextContent(/did not match/i)
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/auth/emailCodeForm.test.tsx`
Expected: FAIL, cannot resolve `./EmailCodeForm`.

- [ ] **Step 3: Implement `EmailCodeForm` and slim `SignIn`**

Create `web/src/auth/EmailCodeForm.tsx`:

```tsx
import { useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import { S } from '../lib/strings'
import { Alert, Button } from '../components/ui'

const field =
  'rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900'

/** Email, then the emailed 6-digit code. The same account as the iOS app. */
export function EmailCodeForm({ hint }: { hint?: string }) {
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [step, setStep] = useState<'email' | 'code'>('email')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const sendCode = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    const { error } = await supabase.auth.signInWithOtp({ email: email.trim() })
    setBusy(false)
    if (error) {
      setError(S.signIn.sendFailed)
      return
    }
    setStep('code')
  }

  const verify = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: code.trim(),
      type: 'email',
    })
    setBusy(false)
    if (error) setError(S.signIn.badCode)
  }

  return (
    <div>
      {step === 'email' ? (
        <form onSubmit={sendCode} className="flex flex-col gap-3">
          {hint ? <p className="text-sm text-slate-600">{hint}</p> : null}
          <label className="text-sm font-medium text-slate-700" htmlFor="email">
            {S.signIn.email}
          </label>
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            className={field}
          />
          <Button type="submit" disabled={busy}>
            {S.signIn.sendCode}
          </Button>
        </form>
      ) : (
        <form onSubmit={verify} className="flex flex-col gap-3">
          <p className="text-sm text-slate-600">
            {S.signIn.sentTo} <b>{email.trim()}</b>.
          </p>
          <label className="text-sm font-medium text-slate-700" htmlFor="code">
            {S.signIn.code}
          </label>
          <input
            id="code"
            inputMode="numeric"
            pattern="[0-9]{6}"
            required
            autoComplete="one-time-code"
            value={code}
            onChange={e => setCode(e.target.value)}
            className={`${field} tracking-widest`}
          />
          <Button type="submit" disabled={busy}>
            {S.signIn.submit}
          </Button>
          <Button type="button" variant="ghost" onClick={() => setStep('email')}>
            {S.signIn.differentEmail}
          </Button>
        </form>
      )}
      {error ? (
        <div className="mt-3">
          <Alert tone="error">{error}</Alert>
        </div>
      ) : null}
    </div>
  )
}
```

Replace `web/src/auth/SignIn.tsx` with:

```tsx
import { S } from '../lib/strings'
import { Card } from '../components/ui'
import { EmailCodeForm } from './EmailCodeForm'

export function SignIn() {
  return (
    <main className="mx-auto mt-16 max-w-sm px-4">
      <h1 className="mb-1 text-xl font-semibold text-slate-900">
        {S.signIn.title}
      </h1>
      <p className="mb-4 text-sm text-slate-500">{S.signIn.intro}</p>
      <Card>
        <EmailCodeForm />
      </Card>
    </main>
  )
}
```

- [ ] **Step 4: Run the new and existing auth tests**

Run: `cd web && npx vitest run src/auth src/a11y.test.tsx`
Expected: PASS (the existing `auth.test.tsx` finds `/email/i`, `/send code/i`, `/code/i`, all still present).

- [ ] **Step 5: Commit**

```bash
git add web/src/auth/EmailCodeForm.tsx web/src/auth/SignIn.tsx web/src/auth/emailCodeForm.test.tsx
git commit -m "Onboarding: reusable email-code sign-in form"
```

---

### Task 6: Role-based home (student home, request access)

**Files:**
- Create: `web/src/routes/HomePage.tsx`, `web/src/components/StudentHome.tsx`, `web/src/components/RequestAccess.tsx`
- Modify: `web/src/routes/ClassesPage.tsx` (export `CreateClassCard`), `web/src/routes/router.tsx` (home route component)
- Test: `web/src/routes/HomePage.test.tsx`

**Interfaces:**
- Consumes: `useMyConsoleRole`, `useMyAccessRequest`, `useRequestFacultyAccess`, `useMyStudentClasses`, `useJoinClass` (Task 4).
- Produces: `HomePage()` (route component for `/`), `StudentHome()`, `RequestAccess()`, and `export function CreateClassCard()` from `ClassesPage.tsx`.

- [ ] **Step 1: Write the failing test**

Create `web/src/routes/HomePage.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const state = vi.hoisted(() => ({
  role: 'none' as string,
  request: null as null | { status: string },
  requestMutate: vi.fn(),
  joinClassMutate: vi.fn(),
}))

vi.mock('../lib/api', () => ({
  useMyConsoleRole: () => ({ data: state.role, isPending: false, error: null }),
  useMyAccessRequest: () => ({ data: state.request, isPending: false, error: null }),
  useRequestFacultyAccess: () => ({ mutate: state.requestMutate, isPending: false, error: null }),
  useMyStudentClasses: () => ({
    data: [{ cohort_id: 'c1', name: 'POS 2041-67', term: '2026F', professor: 'Purcell Demo', roster_name: 'Maria Lopez' }],
    isPending: false,
    error: null,
  }),
  useJoinClass: () => ({ mutate: state.joinClassMutate, isPending: false, error: null, isSuccess: false }),
  useMyClasses: () => ({ data: [], isPending: false, error: null }),
  useCreateCohort: () => ({ mutate: vi.fn(), isPending: false, error: null, data: undefined }),
  useFacultyRequests: () => ({ data: [], isPending: false, error: null }),
  useDecideFacultyRequest: () => ({ mutate: vi.fn(), isPending: false }),
  useMintFacultyInvite: () => ({ mutate: vi.fn(), isPending: false, data: undefined, error: null }),
  inviteLink: (c: string) => `link/${c}`,
}))

import { HomePage } from './HomePage'

describe('HomePage', () => {
  beforeEach(() => {
    state.request = null
    state.requestMutate.mockClear()
  })

  it('offers request access to a signed-in user with no role', async () => {
    state.role = 'none'
    render(<HomePage />)
    await userEvent.type(screen.getByLabelText(/^school$/i), 'MDC North')
    await userEvent.type(screen.getByLabelText(/courses you teach/i), 'POS 2041')
    await userEvent.click(screen.getByRole('button', { name: /request access/i }))
    expect(state.requestMutate.mock.calls[0][0]).toEqual({
      school: 'MDC North',
      courses: 'POS 2041',
      note: '',
    })
  })

  it('shows the pending state once a request is open', () => {
    state.role = 'none'
    state.request = { status: 'pending' }
    render(<HomePage />)
    expect(screen.getByText(/request sent/i)).toBeInTheDocument()
  })

  it('gives students their classes, not the faculty console', () => {
    state.role = 'student'
    render(<HomePage />)
    expect(screen.getByText('POS 2041-67')).toBeInTheDocument()
    expect(screen.getByLabelText(/session code/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /create a class/i })).toBeNull()
  })

  it('gives faculty the classes console', () => {
    state.role = 'faculty'
    render(<HomePage />)
    expect(screen.getByRole('button', { name: /create a class/i })).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/routes/HomePage.test.tsx`
Expected: FAIL, cannot resolve `./HomePage`.

- [ ] **Step 3: Implement**

In `web/src/routes/ClassesPage.tsx`, change `function CreateClassCard()` to `export function CreateClassCard()`.

Create `web/src/components/RequestAccess.tsx`:

```tsx
import { useEffect, useState, type FormEvent } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useMyAccessRequest, useRequestFacultyAccess } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card, Spinner } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

export function RequestAccess() {
  const queryClient = useQueryClient()
  const request = useMyAccessRequest()
  const submit = useRequestFacultyAccess()
  const [school, setSchool] = useState('')
  const [courses, setCourses] = useState('')
  const [note, setNote] = useState('')
  const status = request.data?.status

  // Approval happens elsewhere (the request poll picks it up); once it
  // lands, re-resolve the home so the faculty console appears.
  useEffect(() => {
    if (status === 'approved') {
      void queryClient.invalidateQueries({ queryKey: ['console-role'] })
    }
  }, [status, queryClient])

  if (request.isPending) return <Spinner />

  const onSubmit = (e: FormEvent) => {
    e.preventDefault()
    submit.mutate({ school: school.trim(), courses: courses.trim(), note: note.trim() })
  }

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-4">
      <Card>
        <h1 className="text-lg font-semibold text-slate-900">{S.requestAccess.title}</h1>
        <p className="mt-1 text-sm text-slate-600">{S.requestAccess.intro}</p>
        {status === 'pending' ? (
          <div className="mt-3">
            <Alert tone="info">{S.requestAccess.pending}</Alert>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="mt-3 flex flex-col gap-3">
            {status === 'denied' ? <Alert tone="error">{S.requestAccess.denied}</Alert> : null}
            <label className="text-sm text-slate-700">
              {S.requestAccess.school}
              <input required minLength={2} maxLength={120} value={school}
                onChange={e => setSchool(e.target.value)} className={field} />
            </label>
            <label className="text-sm text-slate-700">
              {S.requestAccess.courses}
              <input required minLength={2} maxLength={200} value={courses}
                placeholder={S.requestAccess.coursesPlaceholder}
                onChange={e => setCourses(e.target.value)} className={field} />
            </label>
            <label className="text-sm text-slate-700">
              {S.requestAccess.note}
              <textarea rows={2} maxLength={500} value={note}
                onChange={e => setNote(e.target.value)} className={field} />
            </label>
            {submit.error ? <Alert tone="error">{submit.error.message}</Alert> : null}
            <div>
              <Button type="submit" disabled={submit.isPending}>{S.requestAccess.submit}</Button>
            </div>
          </form>
        )}
      </Card>
      <p className="text-center text-sm text-slate-500">
        {S.requestAccess.studentInstead}{' '}
        <a href="#/join" className="font-medium text-slate-900 underline">{S.student.joinSession}</a>
      </p>
    </div>
  )
}
```

Create `web/src/components/StudentHome.tsx`:

```tsx
import { useState, type FormEvent } from 'react'
import { useJoinClass, useMyStudentClasses } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card, Spinner } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

export function StudentHome() {
  const classes = useMyStudentClasses()
  const joinClass = useJoinClass()
  const [sessionCode, setSessionCode] = useState('')
  const [classCode, setClassCode] = useState('')
  const [rosterName, setRosterName] = useState('')

  const goToSession = (e: FormEvent) => {
    e.preventDefault()
    window.location.hash = `#/join?code=${sessionCode.trim().toUpperCase()}`
  }
  const onJoinClass = (e: FormEvent) => {
    e.preventDefault()
    joinClass.mutate({ code: classCode.trim().toUpperCase(), rosterName: rosterName.trim() })
  }

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-4">
      <Card>
        <h2 className="mb-2 text-sm font-semibold text-slate-900">{S.student.joinSession}</h2>
        <form onSubmit={goToSession} className="flex items-end gap-2">
          <label className="flex-1 text-sm text-slate-700">
            {S.student.sessionCode}
            <input required value={sessionCode}
              onChange={e => setSessionCode(e.target.value.toUpperCase())}
              className={`${field} font-semibold tracking-[0.3em] uppercase`} />
          </label>
          <Button type="submit">{S.student.join}</Button>
        </form>
      </Card>
      <Card>
        <h1 className="mb-2 text-sm font-semibold text-slate-900">{S.student.title}</h1>
        {classes.isPending ? <Spinner /> : null}
        {classes.data && classes.data.length === 0 ? (
          <p className="text-sm text-slate-500">{S.student.none}</p>
        ) : null}
        <ul className="flex flex-col divide-y divide-slate-100">
          {(classes.data ?? []).map(c => (
            <li key={c.cohort_id} className="flex items-center justify-between py-2">
              <div>
                <p className="text-sm font-medium text-slate-900">{c.name}</p>
                <p className="text-xs text-slate-500">
                  {c.professor}{c.roster_name ? `, you are listed as ${c.roster_name}` : ''}
                </p>
              </div>
              {c.term ? <Badge>{c.term}</Badge> : null}
            </li>
          ))}
        </ul>
      </Card>
      <Card>
        <h2 className="mb-2 text-sm font-semibold text-slate-900">{S.student.joinClass}</h2>
        <form onSubmit={onJoinClass} className="flex flex-col gap-3">
          <label className="text-sm text-slate-700">
            {S.student.classCode}
            <input required value={classCode}
              onChange={e => setClassCode(e.target.value.toUpperCase())}
              className={`${field} uppercase`} />
          </label>
          <label className="text-sm text-slate-700">
            {S.student.rosterName}
            <input required minLength={2} maxLength={60} value={rosterName}
              onChange={e => setRosterName(e.target.value)} className={field} />
          </label>
          {joinClass.error ? <Alert tone="error">{joinClass.error.message}</Alert> : null}
          {joinClass.isSuccess ? <Alert tone="success">{S.student.joined}</Alert> : null}
          <div><Button type="submit" disabled={joinClass.isPending}>{S.student.join}</Button></div>
        </form>
      </Card>
      <p className="text-center text-sm text-slate-500">{S.student.getApp}</p>
    </div>
  )
}
```

Create `web/src/routes/HomePage.tsx`:

```tsx
import { useMyConsoleRole } from '../lib/api'
import { Alert } from '../components/ui'
import { SkeletonStats } from '../components/Skeleton'
import { StudentHome } from '../components/StudentHome'
import { RequestAccess } from '../components/RequestAccess'
import { ClassesPage } from './ClassesPage'

/** One console, the right home per role. The server decides the role. */
export function HomePage() {
  const role = useMyConsoleRole()
  if (role.isPending) return <SkeletonStats count={2} />
  if (role.error) return <Alert tone="error">{role.error.message}</Alert>
  if (role.data === 'student') return <StudentHome />
  if (role.data === 'none') return <RequestAccess />
  return <ClassesPage />
}
```

In `web/src/routes/router.tsx`, import `HomePage` and set `classesRoute`'s `component: HomePage` (keep the `ClassesPage` import only if still used; remove it otherwise).

Because `RequestAccess` calls `useQueryClient`, wrap renders in `HomePage.test.tsx` with a provider: add at the top of the test file

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
const wrap = (ui: React.ReactElement) =>
  render(<QueryClientProvider client={new QueryClient()}>{ui}</QueryClientProvider>)
```

and replace each `render(<HomePage />)` with `wrap(<HomePage />)`. Import `React` types via `import type React from 'react'` if the linter asks.

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run src/routes/HomePage.test.tsx src/routes/ClassesPage.test.tsx`
Expected: PASS. (If `StaffTools` is not built yet, `ClassesPage` does not import it until Task 7, so these pass now.)

- [ ] **Step 5: Commit**

```bash
git add web/src/routes/HomePage.tsx web/src/routes/HomePage.test.tsx web/src/components/StudentHome.tsx web/src/components/RequestAccess.tsx web/src/routes/ClassesPage.tsx web/src/routes/router.tsx
git commit -m "Onboarding: role-based home with student home and request access"
```

---

### Task 7: Staff tools on the classes page (invite links, request queue)

**Files:**
- Create: `web/src/components/StaffTools.tsx`
- Modify: `web/src/routes/ClassesPage.tsx`
- Test: `web/src/components/staffTools.test.tsx`

**Interfaces:**
- Consumes: `useMyConsoleRole`, `useMintFacultyInvite`, `inviteLink`, `useFacultyRequests`, `useDecideFacultyRequest` (Task 4).
- Produces: `StaffTools()`; renders the invite card for `staff` and `faculty`, and the request queue for `staff` only.

- [ ] **Step 1: Write the failing test**

Create `web/src/components/staffTools.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const s = vi.hoisted(() => ({
  role: 'staff',
  mint: vi.fn((_a: unknown, o?: { onSuccess?: (c: string) => void }) => o?.onSuccess?.('D7QMJA')),
  decide: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  useMyConsoleRole: () => ({ data: s.role }),
  useMintFacultyInvite: () => ({ mutate: s.mint, isPending: false, error: null }),
  inviteLink: (c: string) => `https://politiface.app/app/#/welcome?invite=${c}`,
  useFacultyRequests: (enabled: boolean) => ({
    data: enabled
      ? [{ id: 'r1', user_id: 'u1', handle: 'jmalagon', email: 'jm@mdc.edu', school: 'MDC North', courses: 'POS 2041', note: null, created_at: '2026-09-28T12:00:00Z' }]
      : undefined,
    isPending: false,
    error: null,
  }),
  useDecideFacultyRequest: () => ({ mutate: s.decide, isPending: false }),
}))

import { StaffTools } from './StaffTools'

describe('StaffTools', () => {
  it('mints an invite and shows the welcome link', async () => {
    render(<StaffTools />)
    await userEvent.type(screen.getByLabelText(/their email/i), 'new@mdc.edu')
    await userEvent.click(screen.getByRole('button', { name: /create invite link/i }))
    expect(s.mint.mock.calls[0][0]).toEqual({ recipientEmail: 'new@mdc.edu', note: '' })
    expect(screen.getByDisplayValue(/#\/welcome\?invite=D7QMJA/)).toBeInTheDocument()
  })

  it('staff approve a pending request', async () => {
    render(<StaffTools />)
    expect(screen.getByText(/jm@mdc\.edu/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /approve/i }))
    expect(s.decide.mock.calls[0][0]).toEqual({ id: 'r1', approve: true })
  })

  it('faculty get invites but not the request queue', () => {
    s.role = 'faculty'
    render(<StaffTools />)
    expect(screen.getByRole('button', { name: /create invite link/i })).toBeInTheDocument()
    expect(screen.queryByText(/instructor requests/i)).toBeNull()
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/components/staffTools.test.tsx`
Expected: FAIL, cannot resolve `./StaffTools`.

- [ ] **Step 3: Implement**

Create `web/src/components/StaffTools.tsx`:

```tsx
import { useState, type FormEvent } from 'react'
import {
  inviteLink,
  useDecideFacultyRequest,
  useFacultyRequests,
  useMintFacultyInvite,
  useMyConsoleRole,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

function InviteCard() {
  const mint = useMintFacultyInvite()
  const [recipient, setRecipient] = useState('')
  const [note, setNote] = useState('')
  const [link, setLink] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  const submit = (e: FormEvent) => {
    e.preventDefault()
    setCopied(false)
    mint.mutate(
      { recipientEmail: recipient.trim(), note: note.trim() },
      { onSuccess: code => setLink(inviteLink(code)) },
    )
  }

  return (
    <Card>
      <h2 className="text-sm font-semibold text-slate-900">{S.staffTools.inviteTitle}</h2>
      <p className="mt-1 text-sm text-slate-500">{S.staffTools.inviteHint}</p>
      <form onSubmit={submit} className="mt-3 flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.staffTools.recipient}
          <input type="email" value={recipient} onChange={e => setRecipient(e.target.value)} className={field} />
        </label>
        <label className="text-sm text-slate-700">
          {S.staffTools.note}
          <input maxLength={120} value={note} onChange={e => setNote(e.target.value)} className={field} />
        </label>
        {mint.error ? <Alert tone="error">{mint.error.message}</Alert> : null}
        <div><Button type="submit" disabled={mint.isPending}>{S.staffTools.mint}</Button></div>
      </form>
      {link ? (
        <div className="mt-3 flex items-center gap-2">
          <input readOnly aria-label="Invite link" value={link} className={`${field} mt-0`}
            onFocus={e => e.currentTarget.select()} />
          <Button variant="ghost" onClick={() => {
            void navigator.clipboard?.writeText(link)
            setCopied(true)
          }}>
            {copied ? S.staffTools.copied : S.staffTools.copy}
          </Button>
        </div>
      ) : null}
    </Card>
  )
}

function RequestQueue() {
  const requests = useFacultyRequests(true)
  const decide = useDecideFacultyRequest()
  return (
    <Card>
      <h2 className="mb-2 text-sm font-semibold text-slate-900">{S.staffTools.requestsTitle}</h2>
      {requests.error ? <Alert tone="error">{requests.error.message}</Alert> : null}
      {requests.data && requests.data.length === 0 ? (
        <p className="text-sm text-slate-500">{S.staffTools.noRequests}</p>
      ) : null}
      <ul className="flex flex-col divide-y divide-slate-100">
        {(requests.data ?? []).map(r => (
          <li key={r.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
            <div className="min-w-0">
              <p className="text-sm font-medium text-slate-900">{r.handle}, {r.email}</p>
              <p className="text-xs text-slate-500">
                {r.school}, {r.courses}{r.note ? `. ${r.note}` : ''}
              </p>
            </div>
            <div className="flex gap-2">
              <Button disabled={decide.isPending}
                onClick={() => decide.mutate({ id: r.id, approve: true })}>
                {S.staffTools.approve}
              </Button>
              <Button variant="ghost" disabled={decide.isPending}
                onClick={() => decide.mutate({ id: r.id, approve: false })}>
                {S.staffTools.deny}
              </Button>
            </div>
          </li>
        ))}
      </ul>
    </Card>
  )
}

/** Onboarding tools until the phase 2 admin console replaces them. */
export function StaffTools() {
  const role = useMyConsoleRole()
  if (role.data !== 'staff' && role.data !== 'faculty') return null
  return (
    <div className="mt-6 grid gap-4 lg:grid-cols-2">
      <InviteCard />
      {role.data === 'staff' ? <RequestQueue /> : null}
    </div>
  )
}
```

In `web/src/routes/ClassesPage.tsx`, import `StaffTools` and render `<StaffTools />` as the last child in both returned trees: after `<CreateClassCard />` in the empty-state branch, and after the `<div className="mt-4"><CreateClassCard /></div>` block in the list branch.

In `web/src/routes/ClassesPage.test.tsx` and `web/src/a11y.test.tsx`, add to each `vi.mock('./lib/api' | '../lib/api', ...)` factory:

```ts
  useMyConsoleRole: () => ({ data: 'faculty' }),
  useMintFacultyInvite: () => ({ mutate: vi.fn(), isPending: false, error: null }),
  inviteLink: (c: string) => c,
  useFacultyRequests: () => ({ data: [], isPending: false, error: null }),
  useDecideFacultyRequest: () => ({ mutate: vi.fn(), isPending: false }),
```

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run src/components/staffTools.test.tsx src/routes/ClassesPage.test.tsx src/a11y.test.tsx`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src/components/StaffTools.tsx web/src/components/staffTools.test.tsx web/src/routes/ClassesPage.tsx web/src/routes/ClassesPage.test.tsx web/src/a11y.test.tsx
git commit -m "Onboarding: invite links and instructor request queue on the classes page"
```

---

### Task 8: Welcome route with setup wizard

**Files:**
- Create: `web/src/routes/WelcomePage.tsx`
- Modify: `web/src/routes/router.tsx`
- Test: `web/src/routes/WelcomePage.test.tsx`

**Interfaces:**
- Consumes: `invitePreview`, `redeemFacultyInvite`, `myConsoleRole`, `useUpdateMyProfile`, `useCreateCohort` (existing; `createCohort` resolves `{ id, join_code }`), `useSession` (`web/src/auth/SessionProvider.tsx`), `EmailCodeForm` (Task 5).
- Produces: public route `#/welcome?invite=CODE` rendering `WelcomePage()`.

Flow: read `invite` from the hash; `invitePreview` (works signed out). Invalid → message. Signed out → title, "Invited by X", `EmailCodeForm`. Signed in → if `myConsoleRole()` is `staff` or `faculty` skip redeem, else `redeemFacultyInvite(code)` once; then step 1 (display name, school) → `update_my_profile`; step 2 (class name, term) → `create_cohort`; then `window.location.hash = '#/class/<id>'`.

- [ ] **Step 1: Write the failing test**

Create `web/src/routes/WelcomePage.test.tsx`:

```tsx
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const m = vi.hoisted(() => ({
  session: null as null | { user: { id: string; is_anonymous: boolean } },
  preview: vi.fn(async () => ({ valid: true, inviter: 'DawoodShah' })),
  role: vi.fn(async () => 'none'),
  redeem: vi.fn(async () => undefined),
  updateProfile: vi.fn((_a: unknown, o?: { onSuccess?: () => void }) => o?.onSuccess?.()),
  createCohort: vi.fn((_a: unknown, o?: { onSuccess?: (d: { id: string; join_code: string }) => void }) =>
    o?.onSuccess?.({ id: 'c9', join_code: 'ABC123' })),
}))

vi.mock('../auth/SessionProvider', () => ({
  useSession: () => ({ session: m.session, loading: false, signOut: vi.fn() }),
}))
vi.mock('../auth/EmailCodeForm', () => ({ EmailCodeForm: () => <p>email code form</p> }))
vi.mock('../lib/api', () => ({
  invitePreview: m.preview,
  myConsoleRole: m.role,
  redeemFacultyInvite: m.redeem,
  useUpdateMyProfile: () => ({ mutate: m.updateProfile, isPending: false, error: null }),
  useCreateCohort: () => ({ mutate: m.createCohort, isPending: false, error: null }),
  useMyProfile: () => ({ data: { handle: 'user_1234abcd', school: null } }),
}))

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WelcomePage } from './WelcomePage'

const wrap = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <WelcomePage />
    </QueryClientProvider>,
  )

describe('WelcomePage', () => {
  beforeEach(() => {
    window.location.hash = '#/welcome?invite=d7qmja'
    m.session = null
    m.redeem.mockClear()
    m.createCohort.mockClear()
  })

  it('signed out: shows the inviter and the email-code form', async () => {
    wrap()
    expect(await screen.findByText(/DawoodShah/)).toBeInTheDocument()
    expect(screen.getByText('email code form')).toBeInTheDocument()
    expect(m.preview).toHaveBeenCalledWith('D7QMJA')
  })

  it('expired link: says so and offers no sign-in', async () => {
    m.preview.mockResolvedValueOnce({ valid: false, inviter: null })
    wrap()
    expect(await screen.findByText(/expired or was already used/i)).toBeInTheDocument()
    expect(screen.queryByText('email code form')).toBeNull()
  })

  it('signed in: redeems once, then profile, then first class, then opens it', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    wrap()
    await waitFor(() => expect(m.redeem).toHaveBeenCalledWith('D7QMJA'))
    const name = await screen.findByLabelText(/display name/i)
    expect(name).toHaveValue('')
    await userEvent.type(name, 'Purcell Demo')
    await userEvent.type(screen.getByLabelText(/^school$/i), 'MDC North')
    await userEvent.click(screen.getByRole('button', { name: /next/i }))
    await userEvent.type(await screen.findByLabelText(/class name/i), 'POS 2041-67')
    await userEvent.type(screen.getByLabelText(/term/i), '2026F')
    await userEvent.click(screen.getByRole('button', { name: /create class/i }))
    expect(m.createCohort.mock.calls[0][0]).toEqual({ name: 'POS 2041-67', term: '2026F' })
    expect(window.location.hash).toBe('#/class/c9')
    expect(m.redeem).toHaveBeenCalledTimes(1)
  })

  it('already an instructor: skips redeeming', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.role.mockResolvedValueOnce('faculty')
    wrap()
    expect(await screen.findByLabelText(/display name/i)).toBeInTheDocument()
    expect(m.redeem).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/routes/WelcomePage.test.tsx`
Expected: FAIL, cannot resolve `./WelcomePage`.

- [ ] **Step 3: Implement**

Create `web/src/routes/WelcomePage.tsx`:

```tsx
import { useEffect, useState, type FormEvent } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useSession } from '../auth/SessionProvider'
import { EmailCodeForm } from '../auth/EmailCodeForm'
import {
  invitePreview,
  myConsoleRole,
  redeemFacultyInvite,
  useCreateCohort,
  useMyProfile,
  useUpdateMyProfile,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card, Spinner } from '../components/ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

function inviteFromHash(): string {
  const m = window.location.hash.match(/[?&]invite=([A-Za-z0-9]+)/)
  return m ? m[1].toUpperCase() : ''
}

// Generated handles ("user_1a2b...") are placeholders, not names.
const isGenerated = (h: string | undefined) => !h || /^user_[0-9a-f]{8,12}$/.test(h)

function Setup({ userId }: { userId: string }) {
  const profile = useMyProfile(userId)
  const update = useUpdateMyProfile()
  const create = useCreateCohort()
  const [step, setStep] = useState<'profile' | 'class'>('profile')
  const [handle, setHandle] = useState('')
  const [school, setSchool] = useState('')
  const [name, setName] = useState('')
  const [term, setTerm] = useState('')
  const [seeded, setSeeded] = useState(false)

  if (!seeded && profile.data) {
    setSeeded(true)
    if (!isGenerated(profile.data.handle)) setHandle(profile.data.handle)
    setSchool(profile.data.school ?? '')
  }

  const saveProfile = (e: FormEvent) => {
    e.preventDefault()
    update.mutate(
      { handle: handle.trim(), school: school.trim() },
      { onSuccess: () => setStep('class') },
    )
  }
  const createClass = (e: FormEvent) => {
    e.preventDefault()
    create.mutate(
      { name: name.trim(), term: term.trim() || null },
      {
        onSuccess: d => {
          window.location.hash = `#/class/${(d as { id: string }).id}`
        },
      },
    )
  }

  return step === 'profile' ? (
    <Card>
      <h2 className="text-base font-semibold text-slate-900">{S.welcome.stepProfile}</h2>
      <p className="mt-1 text-sm text-slate-500">{S.welcome.profileHint}</p>
      <form onSubmit={saveProfile} className="mt-3 flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.account.displayName}
          <input required minLength={3} maxLength={30} value={handle}
            onChange={e => setHandle(e.target.value)} className={field} />
        </label>
        <label className="text-sm text-slate-700">
          {S.account.school}
          <input maxLength={120} value={school}
            onChange={e => setSchool(e.target.value)} className={field} />
        </label>
        {update.error ? <Alert tone="error">{update.error.message}</Alert> : null}
        <div><Button type="submit" disabled={update.isPending}>{S.welcome.next}</Button></div>
      </form>
    </Card>
  ) : (
    <Card>
      <h2 className="text-base font-semibold text-slate-900">{S.welcome.stepClass}</h2>
      <p className="mt-1 text-sm text-slate-500">{S.welcome.classHint}</p>
      <form onSubmit={createClass} className="mt-3 flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.welcome.className}
          <input required minLength={3} value={name} placeholder={S.welcome.classNamePlaceholder}
            onChange={e => setName(e.target.value)} className={field} />
        </label>
        <label className="text-sm text-slate-700">
          {S.welcome.term}
          <input value={term} placeholder="2026F"
            onChange={e => setTerm(e.target.value)} className={field} />
        </label>
        {create.error ? <Alert tone="error">{create.error.message}</Alert> : null}
        <div><Button type="submit" disabled={create.isPending}>{S.welcome.createClass}</Button></div>
      </form>
    </Card>
  )
}

function Verify({ code, userId }: { code: string; userId: string }) {
  // Instructors who already have access skip the redeem (it would burn the code).
  const verified = useQuery({
    queryKey: ['welcome', 'verify', code, userId],
    queryFn: async () => {
      const role = await myConsoleRole()
      if (role !== 'staff' && role !== 'faculty') await redeemFacultyInvite(code)
      return true
    },
    retry: false,
    staleTime: Infinity,
  })
  if (verified.isPending) return <Spinner label={S.welcome.verifying} />
  if (verified.error) return <Alert tone="error">{verified.error.message}</Alert>
  return <Setup userId={userId} />
}

export function WelcomePage() {
  const { session } = useSession()
  const [code] = useState(inviteFromHash)
  const preview = useQuery({
    queryKey: ['invite-preview', code],
    queryFn: () => invitePreview(code),
    enabled: code !== '',
    retry: false,
  })
  const signedIn = session !== null && !session.user.is_anonymous

  useEffect(() => {
    document.title = 'Politiface: instructor invite'
  }, [])

  // Signed in, the redeem itself is the check: a professor who already
  // redeemed this code (so it previews as used) is verified and skips it.
  return (
    <main className="mx-auto mt-12 flex max-w-md flex-col gap-4 px-4">
      <h1 className="text-xl font-semibold text-slate-900">{S.welcome.title}</h1>
      {code === '' ? (
        <Alert tone="error">{S.welcome.invalid}</Alert>
      ) : signedIn ? (
        <Verify code={code} userId={session.user.id} />
      ) : preview.isPending ? (
        <Spinner />
      ) : preview.error ? (
        <Alert tone="error">{preview.error.message}</Alert>
      ) : !preview.data.valid ? (
        <Alert tone="error">{S.welcome.invalid}</Alert>
      ) : (
        <>
          {preview.data?.inviter ? (
            <p className="text-sm text-slate-600">
              {S.welcome.invitedBy} <b>{preview.data.inviter}</b>
            </p>
          ) : null}
          <Card>
            <EmailCodeForm />
          </Card>
        </>
      )}
    </main>
  )
}
```

In `web/src/routes/router.tsx`, add a public route next to `joinRoute`:

```tsx
import { WelcomePage } from './WelcomePage'

// Public: professors land here from an invite link and sign in on the page.
const welcomeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/welcome',
  component: WelcomePage,
})
```

and add `welcomeRoute,` to `rootRoute.addChildren([...])` next to `joinRoute`.

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run src/routes/WelcomePage.test.tsx`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src/routes/WelcomePage.tsx web/src/routes/WelcomePage.test.tsx web/src/routes/router.tsx
git commit -m "Onboarding: invite link welcome page with first-class setup"
```

---

### Task 9: Join page, signed-in students

**Files:**
- Rewrite: `web/src/routes/JoinPage.tsx` (keep the existing `GuestSession`, `GuestReveal`, `GuestEnded` components unchanged except renaming `GuestSession` to `SessionView`)
- Rewrite: `web/src/routes/JoinPage.test.tsx`

**Interfaces:**
- Consumes: `liveSessionPreview`, `joinLiveSession`, `joinLiveSessionAsStudent`, `signInAnonymously`, `joinLiveSessionGuest`, `useSession`, `EmailCodeForm`.
- Produces: `JoinPage()` with branches: no code → code entry; signed out → preview + sign-in (+ guest option when allowed); signed in teaching → "you teach this class"; member → "Join as X"; not a member → roster name + join.

- [ ] **Step 1: Write the failing tests**

Replace `web/src/routes/JoinPage.test.tsx` with:

```tsx
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const joined = {
  id: 's1', title: 'Week 3 quiz', status: 'lobby', index: -1, total: 5, question_seconds: 20,
}
const m = vi.hoisted(() => ({
  session: null as null | { user: { id: string; is_anonymous: boolean } },
  preview: vi.fn(),
  joinMember: vi.fn(),
  joinStudent: vi.fn(),
  signInAnonymously: vi.fn(async () => ({})),
  joinGuest: vi.fn(),
  signOut: vi.fn(async () => undefined),
}))

vi.mock('../auth/SessionProvider', () => ({
  useSession: () => ({ session: m.session, loading: false, signOut: m.signOut }),
}))
vi.mock('../auth/EmailCodeForm', () => ({ EmailCodeForm: () => <p>email code form</p> }))
vi.mock('../lib/api', () => ({
  liveSessionPreview: m.preview,
  joinLiveSession: m.joinMember,
  joinLiveSessionAsStudent: m.joinStudent,
  signInAnonymously: m.signInAnonymously,
  joinLiveSessionGuest: m.joinGuest,
  submitLiveAnswer: vi.fn(),
  liveReveal: vi.fn(),
  liveScoreboard: vi.fn(async () => []),
}))
vi.mock('../lib/live', () => ({
  useLiveSession: () => ({ state: { status: 'lobby' }, error: null }),
}))

import { JoinPage } from './JoinPage'

const basePreview = {
  title: 'Week 3 quiz', status: 'lobby', allow_guests: false,
  class_name: 'POS 2041-67', professor: 'Purcell Demo',
  is_member: false, role: null, roster_name: null,
}
const wrap = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <JoinPage />
    </QueryClientProvider>,
  )

describe('JoinPage', () => {
  beforeEach(() => {
    window.location.hash = '#/join?code=abc123'
    m.session = null
    for (const f of [m.preview, m.joinMember, m.joinStudent, m.joinGuest]) f.mockReset()
    m.preview.mockResolvedValue(basePreview)
    m.joinMember.mockResolvedValue(joined)
    m.joinStudent.mockResolvedValue(joined)
    m.joinGuest.mockResolvedValue(joined)
  })

  it('signed out: shows the class and asks to sign in, no guest option by default', async () => {
    wrap()
    expect(await screen.findByText(/POS 2041-67/)).toBeInTheDocument()
    expect(screen.getByText(/Purcell Demo/)).toBeInTheDocument()
    expect(screen.getByText('email code form')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /without signing in/i })).toBeNull()
    expect(m.preview).toHaveBeenCalledWith('ABC123')
  })

  it('signed out, guests allowed: the guest path still works', async () => {
    m.preview.mockResolvedValue({ ...basePreview, allow_guests: true })
    wrap()
    await userEvent.click(await screen.findByRole('button', { name: /without signing in/i }))
    await userEvent.type(screen.getByLabelText(/your name/i), 'Alex R')
    await userEvent.click(screen.getByRole('button', { name: /^join$/i }))
    expect(m.signInAnonymously).toHaveBeenCalled()
    expect(m.joinGuest).toHaveBeenCalledWith('ABC123', 'Alex R')
    expect(await screen.findByText(/waiting for your instructor/i)).toBeInTheDocument()
  })

  it('signed in, first time: asks for the roster name and enrolls', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    wrap()
    await userEvent.type(await screen.findByLabelText(/as your professor knows it/i), 'Maria Lopez')
    await userEvent.click(screen.getByRole('button', { name: /join pos 2041-67/i }))
    expect(m.joinStudent).toHaveBeenCalledWith('ABC123', 'Maria Lopez')
    expect(await screen.findByText(/waiting for your instructor/i)).toBeInTheDocument()
  })

  it('signed in member: one tap', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.preview.mockResolvedValue({ ...basePreview, is_member: true, role: 'student', roster_name: 'Maria Lopez' })
    wrap()
    await userEvent.click(await screen.findByRole('button', { name: /join as maria lopez/i }))
    expect(m.joinMember).toHaveBeenCalledWith('ABC123')
  })

  it('signed in faculty of the class: sent back to the console', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.preview.mockResolvedValue({ ...basePreview, is_member: true, role: 'faculty' })
    wrap()
    expect(await screen.findByText(/you teach this class/i)).toBeInTheDocument()
  })

  it('not you: signs out', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    wrap()
    await userEvent.click(await screen.findByRole('button', { name: /not you/i }))
    expect(m.signOut).toHaveBeenCalled()
  })

  it('no code in the link: asks for one', async () => {
    window.location.hash = '#/join'
    wrap()
    await userEvent.type(screen.getByLabelText(/session code/i), 'xyz789')
    await userEvent.click(screen.getByRole('button', { name: /continue/i }))
    expect(m.preview).toHaveBeenCalledWith('XYZ789')
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/routes/JoinPage.test.tsx`
Expected: FAIL (no preview call, missing buttons).

- [ ] **Step 3: Implement**

In `web/src/routes/JoinPage.tsx`:

1. Update imports:

```tsx
import { useState, type FormEvent } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  joinLiveSession,
  joinLiveSessionAsStudent,
  joinLiveSessionGuest,
  liveReveal,
  liveScoreboard,
  liveSessionPreview,
  signInAnonymously,
  submitLiveAnswer,
  type LiveJoin,
  type LiveRevealData,
  type ScoreboardRow,
  type SessionPreview,
} from '../lib/api'
import { useSession } from '../auth/SessionProvider'
import { EmailCodeForm } from '../auth/EmailCodeForm'
import { useLiveSession } from '../lib/live'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card, Spinner } from '../components/ui'
import { Countdown } from '../components/Countdown'
import { Scoreboard } from '../components/Scoreboard'
```

2. Delete the old `JoinForm` component. Rename `GuestSession` to `SessionView` (body unchanged).

3. Add these components and replace `JoinPage`:

```tsx
const field =
  'rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900'

function CodeEntry({ onCode }: { onCode: (c: string) => void }) {
  const [code, setCode] = useState('')
  return (
    <Card>
      <form
        onSubmit={e => {
          e.preventDefault()
          onCode(code.trim().toUpperCase())
        }}
        className="flex flex-col gap-3"
      >
        <label className="text-sm font-medium text-slate-700" htmlFor="join-code">
          {S.student.sessionCode}
        </label>
        <input id="join-code" required autoComplete="off" value={code}
          onChange={e => setCode(e.target.value.toUpperCase())}
          className={`${field} text-center text-lg font-semibold tracking-[0.3em] uppercase`} />
        <Button type="submit">Continue</Button>
      </form>
    </Card>
  )
}

function GuestJoin({ code, onJoined }: { code: string; onJoined: (s: LiveJoin) => void }) {
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signInAnonymously()
      onJoined(await joinLiveSessionGuest(code, name.trim()))
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setBusy(false)
    }
  }
  return (
    <Card>
      <p className="mb-3 text-sm text-slate-500">{S.join.guestNote}</p>
      <form onSubmit={e => void submit(e)} className="flex flex-col gap-3">
        <label className="text-sm font-medium text-slate-700" htmlFor="guest-name">
          {S.join.guestName}
        </label>
        <input id="guest-name" required minLength={2} maxLength={40} value={name}
          onChange={e => setName(e.target.value)} className={field} />
        <Button type="submit" disabled={busy}>Join</Button>
      </form>
      {error ? <div className="mt-3"><Alert tone="error">{error}</Alert></div> : null}
    </Card>
  )
}

function StudentJoin({
  code, preview, onJoined,
}: { code: string; preview: SessionPreview; onJoined: (s: LiveJoin) => void }) {
  const { signOut } = useSession()
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const run = async (fn: () => Promise<LiveJoin>) => {
    setBusy(true)
    setError(null)
    try {
      onJoined(await fn())
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setBusy(false)
    }
  }

  const teaching = preview.role === 'faculty' || preview.role === 'ta'

  return (
    <Card>
      {teaching ? (
        <p className="text-sm text-slate-700">
          {S.errors.youTeach}{' '}
          <a href="#/" className="font-medium underline">Open your console</a>
        </p>
      ) : preview.is_member ? (
        <Button disabled={busy} className="w-full justify-center"
          onClick={() => void run(() => joinLiveSession(code))}>
          {S.join.joinAs} {preview.roster_name ?? 'yourself'}
        </Button>
      ) : (
        <form
          onSubmit={e => {
            e.preventDefault()
            void run(() => joinLiveSessionAsStudent(code, name.trim()))
          }}
          className="flex flex-col gap-3"
        >
          <label className="text-sm font-medium text-slate-700" htmlFor="roster-name">
            {S.join.firstTimeName}
          </label>
          <input id="roster-name" required minLength={2} maxLength={60} value={name}
            autoComplete="name" onChange={e => setName(e.target.value)} className={field} />
          <Button type="submit" disabled={busy}>
            {S.join.joinClass} {preview.class_name}
          </Button>
        </form>
      )}
      {error ? <div className="mt-3"><Alert tone="error">{error}</Alert></div> : null}
      <div className="mt-3 text-center">
        <Button variant="ghost" onClick={() => void signOut()}>{S.join.notYou}</Button>
      </div>
    </Card>
  )
}

function codeFromHash(): string {
  const m = window.location.hash.match(/[?&]code=([A-Za-z0-9]+)/)
  return m ? m[1].toUpperCase() : ''
}

export function JoinPage() {
  const { session } = useSession()
  const [code, setCode] = useState(codeFromHash)
  const [joined, setJoined] = useState<LiveJoin | null>(null)
  const [asGuest, setAsGuest] = useState(false)
  const signedIn = session !== null && !session.user.is_anonymous
  const preview = useQuery({
    queryKey: ['live-preview', code, signedIn ? session.user.id : 'signed-out'],
    queryFn: () => liveSessionPreview(code),
    enabled: code !== '',
    retry: false,
  })

  if (joined) return <SessionView joined={joined} />

  return (
    <main className="mx-auto mt-12 flex max-w-sm flex-col gap-4 px-4">
      <h1 className="text-xl font-semibold text-slate-900">{S.join.title}</h1>
      {code === '' ? (
        <CodeEntry onCode={setCode} />
      ) : preview.isPending ? (
        <Spinner />
      ) : preview.error ? (
        <>
          <Alert tone="error">{preview.error.message}</Alert>
          <CodeEntry onCode={setCode} />
        </>
      ) : (
        <>
          <Card>
            <p className="text-base font-semibold text-slate-900">{preview.data.title}</p>
            <p className="text-sm text-slate-600">
              {preview.data.class_name}
              {preview.data.professor ? ` ${S.join.with} ${preview.data.professor}` : ''}
            </p>
          </Card>
          {signedIn ? (
            <StudentJoin code={code} preview={preview.data} onJoined={setJoined} />
          ) : asGuest ? (
            <GuestJoin code={code} onJoined={setJoined} />
          ) : (
            <>
              <Card>
                <EmailCodeForm hint={S.join.signInIntro} />
              </Card>
              {preview.data.allow_guests ? (
                <Button variant="ghost" onClick={() => setAsGuest(true)}>
                  {S.join.guest}
                </Button>
              ) : null}
            </>
          )}
        </>
      )}
    </main>
  )
}
```

Keep `SessionView`, `GuestReveal`, `GuestEnded` as they were. The preview query key includes the user id, so after sign-in the preview refetches with membership and the page moves to `StudentJoin` without a reload.

- [ ] **Step 4: Keep the accessibility test rendering the join page**

`web/src/a11y.test.tsx` renders `<JoinPage />` with no providers; the new page uses `useQuery` and `useSession`. In that file:
- add `liveSessionPreview: vi.fn(), joinLiveSession: vi.fn(), joinLiveSessionAsStudent: vi.fn(),` to the `vi.mock('./lib/api', ...)` factory;
- add `vi.mock('./auth/SessionProvider', () => ({ useSession: () => ({ session: null, loading: false, signOut: vi.fn() }) }))`;
- in the join-page test, render inside a provider:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
// ...
    window.location.hash = '#/join'
    await expectNoViolations(
      <QueryClientProvider client={new QueryClient()}>
        <JoinPage />
      </QueryClientProvider>,
    )
```

If mocking `SessionProvider` breaks another test in the same file that relies on the real provider, scope the mock by returning the real module's other exports: `vi.mock('./auth/SessionProvider', async orig => ({ ...(await orig()), useSession: () => ({ session: null, loading: false, signOut: vi.fn() }) }))`.

- [ ] **Step 5: Run tests**

Run: `cd web && npx vitest run src/routes/JoinPage.test.tsx src/a11y.test.tsx`
Expected: PASS (7 join tests; a11y unchanged count).

- [ ] **Step 6: Commit**

```bash
git add web/src/routes/JoinPage.tsx web/src/routes/JoinPage.test.tsx web/src/a11y.test.tsx
git commit -m "Onboarding: browser students sign in once and join as themselves"
```

---

### Task 10: Allow-guests toggle in session setup

**Files:**
- Modify: `web/src/components/LiveTab.tsx` (`LiveDraft`, `emptyLiveDraft`)
- Modify: `web/src/components/QuestionPicker.tsx`
- Test: `web/src/components/questionPicker.test.tsx` (create)

**Interfaces:**
- Consumes: `useCreateLiveSession` args `{ cohortId, title, questionIds, questionSeconds, allowGuests }` (Task 4).
- Produces: `LiveDraft.allowGuests: boolean` (default `false`).

- [ ] **Step 1: Write the failing test**

Create `web/src/components/questionPicker.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'

const create = vi.fn()
vi.mock('../lib/api', () => ({
  usePickableQuestions: () => ({
    data: [{ id: 'q1', stem: 'Which article establishes the judiciary?', domain_id: 2, cohort_id: null }],
    isPending: false,
    error: null,
  }),
  useDomains: () => ({ data: [{ id: 2, name: 'U.S. Constitution' }], isPending: false }),
  useCreateLiveSession: () => ({ mutate: create, isPending: false, error: null }),
}))

import { QuestionPicker } from './QuestionPicker'
import { emptyLiveDraft } from './LiveTab'

function Harness() {
  const [draft, setDraft] = useState({ ...emptyLiveDraft(), composing: true })
  return <QuestionPicker cohortId="c1" draft={draft} onDraftChange={setDraft} onCreated={() => {}} />
}

describe('QuestionPicker guests', () => {
  it('defaults to no guests and passes the toggle through', async () => {
    render(<Harness />)
    const guests = screen.getByLabelText(/allow guests without sign-in/i)
    expect(guests).not.toBeChecked()
    await userEvent.type(screen.getByLabelText(/session title/i), 'Friday review')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(guests)
    await userEvent.click(screen.getByRole('button', { name: /start session/i }))
    expect(create.mock.calls[0][0]).toMatchObject({ allowGuests: true, title: 'Friday review' })
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/components/questionPicker.test.tsx`
Expected: FAIL, no "allow guests" control.

- [ ] **Step 3: Implement**

In `web/src/components/LiveTab.tsx`, add `allowGuests: boolean` to `LiveDraft` and `allowGuests: false,` to `emptyLiveDraft()`.

In `web/src/components/QuestionPicker.tsx`:
- destructure `allowGuests` from `draft` next to `title, seconds, selected`;
- in `submit`, add `allowGuests,` to the `create.mutate` args;
- after the "Seconds per question" `<label>...</label>`, add:

```tsx
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={allowGuests}
            onChange={e => onDraftChange({ ...draft, allowGuests: e.target.checked })}
          />
          Allow guests without sign-in
        </label>
```

- [ ] **Step 4: Run the full web suite, typecheck, lint**

Run: `cd web && npx vitest run && npm run typecheck && npm run lint`
Expected: all tests pass, typecheck clean, lint shows no errors (warnings allowed only where they existed before).

- [ ] **Step 5: Commit**

```bash
git add web/src/components/LiveTab.tsx web/src/components/QuestionPicker.tsx web/src/components/questionPicker.test.tsx
git commit -m "Onboarding: guests are opt-in per live session"
```

---

### Task 11: Ship (founder applies, agent verifies and publishes)

**Files:**
- Modify: `web/src/lib/database.types.ts` (regenerated)
- Modify: `docs/app/**` (built output)

- [ ] **Step 1: Full local verification**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -2 && cd web && npx vitest run && npm run typecheck && npm run build`
Expected: `OK: migrations + smoke test passed`; all web tests pass; build succeeds.

- [ ] **Step 2: Founder applies both pending migrations to production**

Ask the founder to run, in the Supabase SQL editor, in order:
1. `supabase/migrations/20260927000100_display_names_with_spaces.sql`
2. `supabase/migrations/20260928000100_onboarding_phase1.sql`

and then in the SQL editor:
```sql
insert into supabase_migrations.schema_migrations (version, name) values
  ('20260927000100', 'display_names_with_spaces'),
  ('20260928000100', 'onboarding_phase1');
```

Also in the dashboard, Authentication, Rate Limits: set "sign-ups and sign-ins" and "token verifications" to 300 per 5 minutes per IP (a classroom shares one campus IP).

- [ ] **Step 3: Verify production (read-only)**

Run:
```bash
supabase db query --linked "select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and proname in ('invite_preview','revoke_faculty_invite','request_faculty_access','my_faculty_access_request','admin_list_faculty_requests','admin_decide_faculty_request','my_console_role','my_student_classes','live_session_preview','join_live_session_as_student') order by 1"
```
Expected: all 10 names.

- [ ] **Step 4: Regenerate types and confirm they match**

Run: `supabase gen types typescript --project-id sbjpiajjlufrhigmovnk > web/src/lib/database.types.ts.new && diff <(tail -n +5 web/src/lib/database.types.ts) web/src/lib/database.types.ts.new | head -40`
Expected: no semantic differences (only header comment lines). Then keep the 4-line header comment from the old file on top of the generated output, replace the file, run `cd web && npm run typecheck`, and delete the `.new` file.

- [ ] **Step 5: Build, sync, commit, push, PR**

```bash
web/scripts/sync-to-docs.sh
git add web/src/lib/database.types.ts docs/app
git commit -m "Sync built web app to docs/app"
git push origin v2-planning
gh pr create --base main --head v2-planning --title "Onboarding phase 1: invite links, request access, browser students as themselves"
```
If the PR conflicts (it will after a squash merge), follow the routine in memory `web_console_deploy_path.md`: merge `origin/main` into `v2-planning` with v2-planning's side after confirming each conflicting main version exists in v2-planning history, drop stale `docs/app/assets` from main, push, wait for CI, squash-merge.

- [ ] **Step 6: Confirm the live bundle**

Run: `curl -s https://politiface.app/app/index.html | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js'` then grep that bundle for `Allow guests without sign-in` and `You are invited to Politiface as an instructor`.
Expected: both present.

---

### Task 12: In-room test (founder + Dawood, one of Purcell's sections)

No code. Checklist to run before the other six sections:

- [ ] Dawood signs in at `politiface.app/app`, opens the classes page, creates an invite link for Purcell's real email, sends it.
- [ ] Purcell opens the link on his laptop, signs in with the emailed code, completes display name, school, first class; lands on the class page.
- [ ] Purcell creates a live session (guests left off), projects the lobby QR.
- [ ] Ten students join from phones: at least 3 iPhone app users (already members), at least 3 browser-only students on campus Wi-Fi, at least 1 using an `@mymdc.net` address. Record: time from QR to "Waiting for your instructor", any code emails that took over 60 seconds or landed in junk.
- [ ] Run 3 questions to the end. Confirm on the class Students tab that the browser students appear with their roster names.
- [ ] Next session a day later: the same browser students tap "Join as <name>" without signing in again.
- [ ] Log findings in `docs/build-in-public/decision-log.md` and fix blockers before the remaining sections.
