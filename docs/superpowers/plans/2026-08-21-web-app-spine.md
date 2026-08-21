# Web App Backend Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the server-side spine for the web app: hosted-schema verification, database tests in CI, the TA and org-admin role model, disclosure-policy enforcement, the analytics RPCs, and guest live-session join.

**Architecture:** Everything is Postgres migrations on the existing Supabase trust boundary (RLS + SECURITY DEFINER RPCs in `public`, internals in `app`). No new services. The React app (separate plan) consumes only what this plan creates.

**Tech Stack:** Postgres 15+ SQL migrations under `supabase/migrations/`, smoke tests in `supabase/tests/smoke.sql` run by `supabase/tests/run_local.sh`, GitHub Actions for CI.

**Spec:** `docs/superpowers/specs/2026-08-21-web-app-foundation-design.md`

## Global Constraints

- No em-dashes in any Politiface-facing content, including SQL comments and error messages (box-drawing `─` in section rules is fine; it is the existing house pattern).
- Never collect political affiliation or voting history. No new PII columns; guest display names are self-typed and purged on schedule.
- Migrations are additive; never weaken an existing RLS policy or grant.
- Every new `public.*` function gets `revoke ... from public, anon; grant execute ... to authenticated;` (mirror `20260731000100` lines 205-210). Functions in `app.*` get no client grants.
- All SECURITY DEFINER functions set `search_path = public, app, pg_temp` (or `public, pg_temp` when `app` is not referenced).
- NOTHING in this plan is applied to the hosted (production) database automatically. Hosted applies are a founder-approved manual step; this plan only verifies, authors, and tests locally/CI.
- Run `./supabase/tests/run_local.sh` (needs `brew install postgresql@17`; PGBIN defaults to `/opt/homebrew/opt/postgresql@17/bin`) as the test cycle for every migration task.
- Existing RPC output shapes consumed by the live portal (`docs/faculty/index.html`) must stay backward compatible: append columns, never rename or remove.

---

### Task 1: Hosted schema verification (audit F2, deadline Aug 24)

**Files:**
- Create: `docs/audit/08-hosted-schema-verification.md` (docs/audit/ is deliberately untracked; do NOT `git add` it)

**Interfaces:**
- Produces: a verified list of which repo migrations are applied on hosted, and a founder-facing apply list for the gap.

- [ ] **Step 1: Enumerate hosted migrations.** Use the Supabase MCP tools (read-only): `list_projects` to get the project ref for `sbjpiajjlufrhigmovnk`, then `list_migrations`. Record the full list.

- [ ] **Step 2: Enumerate repo migrations.** `ls supabase/migrations/` (25 files, `20260704000100` through `20260806000100`). Diff against Step 1.

- [ ] **Step 3: Spot-check objects for each unapplied candidate.** Audit F2 flagged three migrations as UNAPPLIED, including `20260710000100_cohort_attribution_student_scope.sql` and `20260710000200_objective_readiness.sql` (its header says "UNAPPLIED / DRAFT ... apply MANUALLY"). For each gap, confirm via read-only `execute_sql`:

```sql
select table_name from information_schema.tables
 where table_schema = 'public' and table_name = 'user_objective_readiness';
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'cohorts'
   and column_name in ('reporting_resolution', 'identity_display', 'raw_retention_days');
select routine_name from information_schema.routines
 where routine_schema = 'public'
   and routine_name in ('create_teaching_input', 'locked_question_ids', 'get_open_assessments');
```

- [ ] **Step 4: Write the report.** `docs/audit/08-hosted-schema-verification.md`: table of every repo migration with APPLIED / MISSING status, evidence (query results), and a founder apply list in dependency order. Flag explicitly: Task 5's `student_drilldown` reads `user_objective_readiness`, so `20260710000200` must be applied to hosted before the new analytics migrations are.

- [ ] **Step 5: Report to founder.** Do not commit (directory is untracked). Summarize the apply list in the session; hosted applies happen only with founder approval.

---

### Task 2: Database tests in CI (audit F5)

**Files:**
- Create: `.github/workflows/db-ci.yml`
- Modify: `supabase/tests/run_local.sh:9` (PGBIN default already env-overridable; no change needed unless Step 2 fails)

**Interfaces:**
- Produces: CI job `db-ci / migrations` that every later task's commits must keep green.

- [ ] **Step 1: Write the workflow**

```yaml
name: db-ci
on:
  push:
    branches: [main, v2-planning]
    paths: ['supabase/**', '.github/workflows/db-ci.yml']
  pull_request:
    paths: ['supabase/**', '.github/workflows/db-ci.yml']
jobs:
  migrations:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Ensure Postgres binaries
        run: |
          if [ ! -x /usr/lib/postgresql/16/bin/initdb ]; then
            sudo apt-get update && sudo apt-get install -y postgresql-16
          fi
      - name: Migrations + smoke test
        run: PGBIN=/usr/lib/postgresql/16/bin ./supabase/tests/run_local.sh
```

- [ ] **Step 2: Verify locally that the script honors PGBIN** (it does at line 9; this is the failure-mode check): `PGBIN=/opt/homebrew/opt/postgresql@17/bin ./supabase/tests/run_local.sh`
Expected: `OK: migrations + smoke test passed`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/db-ci.yml
git commit -m "CI: run migrations + smoke test on every supabase change"
```

- [ ] **Step 4: Verify the workflow runs.** Push the branch (or open the PR later) and check `gh run list --workflow=db-ci` shows a green run. If Actions cannot run on this repo config, note it for the founder (a known repo-settings toggle issue exists) and continue; CI greenness is then verified at PR time.

---

### Task 3: TA role and org admins

**Files:**
- Create: `supabase/migrations/20260821000100_roles_ta_org_admins.sql`
- Test: append to `supabase/tests/smoke.sql`

**Interfaces:**
- Consumes: `app.is_cohort_faculty(uuid)`, `app.is_verified_faculty(uuid)`, existing live-session and aggregate RPCs.
- Produces: `app.is_cohort_ta_or_above(p_cohort uuid) returns boolean`, `app.is_org_admin(p_org uuid) returns boolean`, `public.add_cohort_ta(p_cohort uuid, p_email text) returns void`, `public.remove_cohort_ta(p_cohort uuid, p_user uuid) returns void`, `public.my_cohort_role(p_cohort uuid) returns text`. Later tasks and the web app rely on these exact names.

- [ ] **Step 1: Write the failing test.** Append to `supabase/tests/smoke.sql` (new section at the end; new fixed identity):

```sql
-- ── TA role ─────────────────────────────────────────────────────────────────
\set ta_uid '''00000000-0000-0000-0000-0000000000a1'''
reset role;
insert into auth.users (id, email) values (:ta_uid, 'ta@example.edu');
set role authenticated;
set app.test_uid = :ta_uid;
insert into public.profiles (id, handle) values (:ta_uid, 'ta_person');

-- Faculty adds the TA by email.
set app.test_uid = :f_uid;
select public.add_cohort_ta(
  (select id from public.cohorts limit 1), 'ta@example.edu');

do $$
declare v_cohort uuid := (select id from public.cohorts limit 1);
begin
  if (select role from public.cohort_members
       where cohort_id = v_cohort
         and user_id = '00000000-0000-0000-0000-0000000000a1') <> 'ta' then
    raise exception 'TA row not created';
  end if;
end $$;

-- TA can drive a live session and read aggregates.
set app.test_uid = :ta_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts limit 1);
  v_session jsonb;
begin
  v_session := public.create_live_session(
    v_cohort, 'TA quiz',
    (select jsonb_agg(id) from (select id from public.questions
       where cohort_id is null and review_status = 'published'
       limit 3) q),
    20);
  perform public.advance_live_session((v_session ->> 'id')::uuid);
  perform public.cohort_domain_stats(v_cohort, 1);
  perform public.cohort_overview(v_cohort);
end $$;

-- TA is blocked from per-student surfaces.
do $$
declare v_cohort uuid := (select id from public.cohorts limit 1);
begin
  begin
    perform * from public.cohort_student_progress(v_cohort);
    raise exception 'TA read per-student progress; must be blocked';
  exception when others then
    if sqlerrm like '%must be blocked%' then raise; end if;
  end;
end $$;

-- TA cannot add faculty, mint invites, or author questions.
do $$
declare v_cohort uuid := (select id from public.cohorts limit 1);
begin
  begin
    perform public.mint_faculty_invite('nope');
    raise exception 'TA minted an invite; must be blocked';
  exception when others then
    if sqlerrm like '%must be blocked%' then raise; end if;
  end;
  begin
    perform public.create_cohort_question(
      v_cohort, 1::smallint, 'TA question that must fail?',
      '[{"key":"a","text":"A"},{"key":"b","text":"B"}]', 'a');
    raise exception 'TA authored a question; must be blocked';
  exception when others then
    if sqlerrm like '%must be blocked%' then raise; end if;
  end;
end $$;

-- Demote and confirm.
set app.test_uid = :f_uid;
select public.remove_cohort_ta(
  (select id from public.cohorts limit 1),
  '00000000-0000-0000-0000-0000000000a1');
```

- [ ] **Step 2: Run to verify it fails.** `./supabase/tests/run_local.sh`
Expected: FAIL at `add_cohort_ta` (function does not exist).

- [ ] **Step 3: Write the migration** `supabase/migrations/20260821000100_roles_ta_org_admins.sql`:

```sql
-- TA role and org admins.
--
-- TA: a per-cohort helper who can run live sessions and read aggregate
-- analytics, but never per-student data, invites, or question authoring.
-- Org admins: the multi-campus seam. Table and predicate only; surfaces
-- come later. Nothing here weakens an existing policy.

-- ── role column gains 'ta' ──────────────────────────────────────────────────
alter table public.cohort_members drop constraint cohort_members_role_check;
alter table public.cohort_members add constraint cohort_members_role_check
  check (role in ('student', 'faculty', 'ta'));

-- ── org admins ──────────────────────────────────────────────────────────────
create table app.org_admins (
  org_id     uuid not null references public.orgs (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  granted_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create function app.is_org_admin(p_org uuid) returns boolean
language sql stable security definer set search_path = public, app, pg_temp as $$
  select exists (select 1 from app.org_admins
    where org_id = p_org and user_id = auth.uid());
$$;

-- ── predicates ──────────────────────────────────────────────────────────────
create function app.is_cohort_ta_or_above(p_cohort uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.cohort_members
    where cohort_id = p_cohort and user_id = auth.uid()
      and role in ('faculty', 'ta')
  );
$$;

-- The web app asks once per class instead of inferring from errors.
create function public.my_cohort_role(p_cohort uuid) returns text
language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.cohort_members
   where cohort_id = p_cohort and user_id = auth.uid();
$$;
revoke all on function public.my_cohort_role(uuid) from public, anon;
grant execute on function public.my_cohort_role(uuid) to authenticated;

-- ── add / remove TA ─────────────────────────────────────────────────────────
-- Mirrors add_co_faculty (20260729000100): caller must be faculty OF THIS
-- cohort; target looked up by exact email. A TA needs no faculty invite.
-- Never demotes an existing faculty member.
create function public.add_cohort_ta(p_cohort uuid, p_email text)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_caller uuid := auth.uid();
  v_target uuid;
begin
  if v_caller is null then raise exception 'not authenticated'; end if;
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = v_caller and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can add TAs';
  end if;
  select u.id into v_target
    from auth.users u
   where lower(u.email) = lower(trim(p_email));
  if v_target is null then
    raise exception 'no Politiface account uses that email';
  end if;
  if not exists (select 1 from public.profiles where id = v_target) then
    raise exception 'that account has not finished setup yet';
  end if;
  insert into public.cohort_members (cohort_id, user_id, role)
  values (p_cohort, v_target, 'ta')
  on conflict (cohort_id, user_id) do update set role = 'ta'
    where public.cohort_members.role = 'student';
end;
$$;
revoke all on function public.add_cohort_ta(uuid, text) from public, anon;
grant execute on function public.add_cohort_ta(uuid, text) to authenticated;

create function public.remove_cohort_ta(p_cohort uuid, p_user uuid)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can remove TAs';
  end if;
  update public.cohort_members set role = 'student'
   where cohort_id = p_cohort and user_id = p_user and role = 'ta';
  if not found then raise exception 'no TA with that id in this class'; end if;
end;
$$;
revoke all on function public.remove_cohort_ta(uuid, uuid) from public, anon;
grant execute on function public.remove_cohort_ta(uuid, uuid) to authenticated;

-- ── widen session-driving and aggregate gates from faculty to ta-or-above ───
-- Recreate each function with its CURRENT body (source of truth listed
-- below), changing ONLY the gate:
--   app.is_cohort_faculty(X)  ->  app.is_cohort_ta_or_above(X)
-- Functions and their current definitions:
--   create_live_session      20260723000100_live_sessions.sql:85
--   advance_live_session     20260724000100_admin_history_rollups_scoring.sql:291
--   end_live_session         20260724000100_admin_history_rollups_scoring.sql:331
--   live_session_stats       20260723000100_live_sessions.sql:362
--   cohort_live_sessions     20260724000100_admin_history_rollups_scoring.sql:171
--   cohort_overview          20260722000100_audit_hardening.sql:75
--   cohort_domain_stats      20260722000100_audit_hardening.sql:109
--   cohort_top_misses        20260722000100_audit_hardening.sql:139
-- live_reveal and live_scoreboard keep their member checks but their
-- "faculty may look any time" clauses also widen to ta-or-above:
--   live_reveal              20260723000100_live_sessions.sql:296 (line 310)
--   live_scoreboard          20260723000100_live_sessions.sql:327 (line 337)
-- Copy each body verbatim from the listed file and line, apply only the
-- gate substitution, and use `create or replace function`.
-- EXPLICITLY UNCHANGED (faculty-only stays faculty-only): live_session_report,
-- cohort_student_progress, add_co_faculty, mint_faculty_invite, create_cohort,
-- create_cohort_question, retire_cohort_question, create_teaching_input,
-- send_class_announcement, and every RLS policy using app.is_cohort_faculty.

-- my_faculty_overview includes the caller's TA classes too:
-- recreate from 20260724000100:205 changing `role = 'faculty'` in its
-- cohort-selection predicate to `role in ('faculty', 'ta')`.
```

The block comment above is part of the migration file; the actual `create or replace` statements for the eleven listed functions follow it in the same file, produced by verbatim copy plus the single-gate edit.

- [ ] **Step 4: Run to verify it passes.** `./supabase/tests/run_local.sh`
Expected: `OK: migrations + smoke test passed`

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260821000100_roles_ta_org_admins.sql supabase/tests/smoke.sql
git commit -m "Roles: TA per-cohort role and org-admin seam"
```

---

### Task 4: Disclosure-policy chokepoint (audit F1)

**Files:**
- Create: `supabase/migrations/20260821000200_reporting_policy.sql`
- Test: append to `supabase/tests/smoke.sql`

**Interfaces:**
- Consumes: `cohorts.reporting_resolution / identity_display / raw_retention_days` (from `20260731000100`), `app.is_cohort_ta_or_above` (Task 3), `app.is_admin(uuid)` (`20260724000100:32`).
- Produces: `app.effective_resolution(p_cohort uuid) returns text` (raises for non-staff), `app.pseudonym_for(p_cohort uuid, p_user uuid) returns text`, `app.identity_label(p_cohort uuid, p_user uuid, p_roster text, p_handle text) returns text`, `public.set_reporting_policy(p_cohort uuid, p_resolution text, p_identity_display text, p_retention_days int default null) returns void`, `public.log_report_export(p_cohort uuid, p_kind text) returns void`, `public.get_reporting_policy(p_cohort uuid) returns jsonb`. Recreated `live_session_report` and `cohort_student_progress` keep all existing columns unchanged in name and position, and append `student_ref text` as a new last column.

- [ ] **Step 1: Write the failing test.** Append to `supabase/tests/smoke.sql`:

```sql
-- ── Reporting policy chokepoint ─────────────────────────────────────────────
set app.test_uid = :f_uid;

-- Default per_student: named rows with student_ref = user_id.
do $$
declare
  v_cohort uuid := (select id from public.cohorts limit 1);
  r record;
begin
  select * into r from public.cohort_student_progress(v_cohort) limit 1;
  if r.user_id is null or r.student_ref <> r.user_id::text then
    raise exception 'per_student rows must carry user_id and matching ref';
  end if;
end $$;

-- Pseudonymous: stable pseudonym, no user_id, no roster name.
select public.set_reporting_policy(
  (select id from public.cohorts limit 1), 'pseudonymous', 'pseudonym');
do $$
declare
  v_cohort uuid := (select id from public.cohorts limit 1);
  r record; r2 record;
begin
  select * into r from public.cohort_student_progress(v_cohort)
   order by student_ref limit 1;
  if r.user_id is not null then
    raise exception 'pseudonymous rows must not expose user_id';
  end if;
  if r.roster_name not like 'Student %' then
    raise exception 'pseudonymous rows must use pseudonyms, got %', r.roster_name;
  end if;
  select * into r2 from public.cohort_student_progress(v_cohort)
   order by student_ref limit 1;
  if r.student_ref <> r2.student_ref then
    raise exception 'pseudonyms must be stable across calls';
  end if;
end $$;

-- Aggregate only: per-student RPCs refuse.
select public.set_reporting_policy(
  (select id from public.cohorts limit 1), 'aggregate_only', 'pseudonym');
do $$
declare v_cohort uuid := (select id from public.cohorts limit 1);
begin
  begin
    perform * from public.cohort_student_progress(v_cohort);
    raise exception 'aggregate_only cohort disclosed per-student rows';
  exception when others then
    if sqlerrm like '%disclosed per-student%' then raise; end if;
  end;
end $$;

-- Students cannot set policy; exports are logged.
select public.set_reporting_policy(
  (select id from public.cohorts limit 1), 'per_student', 'roster');
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid := (select id from public.cohorts limit 1);
begin
  begin
    perform public.set_reporting_policy(v_cohort, 'per_student', 'roster');
    raise exception 'student set reporting policy; must be blocked';
  exception when others then
    if sqlerrm like '%must be blocked%' then raise; end if;
  end;
end $$;
set app.test_uid = :f_uid;
select public.log_report_export(
  (select id from public.cohorts limit 1), 'csv_progress');
reset role;
do $$
begin
  if (select count(*) from app.export_log) < 1 then
    raise exception 'export was not logged';
  end if;
end $$;
set role authenticated;
```

- [ ] **Step 2: Run to verify it fails.** `./supabase/tests/run_local.sh`
Expected: FAIL at `cohort_student_progress` (no `student_ref` column).

- [ ] **Step 3: Write the migration** `supabase/migrations/20260821000200_reporting_policy.sql`:

```sql
-- Wire the per-cohort reporting policy (20260731000100) into every RPC
-- that returns student-level rows. Server-enforced; clients never filter.
-- TAs are always capped at aggregate_only regardless of cohort policy.

-- ── chokepoint ──────────────────────────────────────────────────────────────
create function app.effective_resolution(p_cohort uuid) returns text
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_role text;
  v_res  text;
begin
  select role into v_role from public.cohort_members
   where cohort_id = p_cohort and user_id = auth.uid();
  if v_role is null and app.is_admin(auth.uid()) then
    v_role := 'faculty';  -- admins audit at the cohort's own policy level
  end if;
  if v_role is null or v_role = 'student' then
    raise exception 'not faculty of this cohort';
  end if;
  if v_role = 'ta' then return 'aggregate_only'; end if;
  select reporting_resolution into v_res from public.cohorts where id = p_cohort;
  return v_res;
end;
$$;

-- Deterministic per cohort and user, so a student keeps one label across
-- every surface, but labels never correlate across cohorts.
create function app.pseudonym_for(p_cohort uuid, p_user uuid) returns text
language sql immutable as $$
  select 'Student ' ||
         upper(substr(md5(p_cohort::text || ':' || p_user::text || ':pf1'), 1, 6));
$$;

create function app.identity_label(
  p_cohort uuid, p_user uuid, p_roster text, p_handle text
) returns text
language sql stable security definer set search_path = public, app, pg_temp as $$
  select case (select identity_display from public.cohorts where id = p_cohort)
           when 'roster'       then coalesce(p_roster, p_handle)
           when 'display_name' then p_handle
           else app.pseudonym_for(p_cohort, p_user)
         end;
$$;

-- ── policy management ───────────────────────────────────────────────────────
create function public.set_reporting_policy(
  p_cohort uuid,
  p_resolution text,
  p_identity_display text,
  p_retention_days int default null
) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can change reporting policy';
  end if;
  update public.cohorts
     set reporting_resolution = p_resolution,
         identity_display     = p_identity_display,
         raw_retention_days   = p_retention_days
   where id = p_cohort;
  -- Column checks from 20260731000100 validate the values.
end;
$$;
revoke all on function public.set_reporting_policy(uuid, text, text, int) from public, anon;
grant execute on function public.set_reporting_policy(uuid, text, text, int) to authenticated;

create function public.get_reporting_policy(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare c record;
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  select reporting_resolution, identity_display, raw_retention_days
    into c from public.cohorts where id = p_cohort;
  return jsonb_build_object(
    'resolution', c.reporting_resolution,
    'identity_display', c.identity_display,
    'raw_retention_days', c.raw_retention_days,
    'effective', app.effective_resolution(p_cohort));
end;
$$;
revoke all on function public.get_reporting_policy(uuid) from public, anon;
grant execute on function public.get_reporting_policy(uuid) to authenticated;

-- ── export audit trail ──────────────────────────────────────────────────────
create table app.export_log (
  id         bigint generated always as identity primary key,
  user_id    uuid not null,
  cohort_id  uuid not null,
  kind       text not null check (kind in
    ('csv_progress', 'csv_at_risk', 'csv_drilldown', 'one_pager', 'session_report')),
  created_at timestamptz not null default now()
);

create function public.log_report_export(p_cohort uuid, p_kind text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  insert into app.export_log (user_id, cohort_id, kind)
  values (auth.uid(), p_cohort, p_kind);
end;
$$;
revoke all on function public.log_report_export(uuid, text) from public, anon;
grant execute on function public.log_report_export(uuid, text) to authenticated;
```

Then, in the same file, recreate the two identified-reporting RPCs. Both bodies are copied from `20260723000200_roster_identity_faculty_gating.sql` (`live_session_report` at line 223, `cohort_student_progress` at line 273) with these exact deltas, and both need `drop function` first because the return type changes:

1. Return table gains a trailing `student_ref text` column.
2. The old `app.is_cohort_faculty` gate is replaced by: `v_res := app.effective_resolution(<cohort_id>);` followed by `if v_res = 'aggregate_only' then raise exception 'this class reports aggregate data only'; end if;` Use exactly that message in both functions. (The smoke test only asserts that the call fails, but the message must NOT contain the phrase 'disclosed per-student', which the test uses as its own failure marker.)
3. Selected columns change per resolution:
   - `per_student`: `user_id` as today, `roster_name` becomes `app.identity_label(cohort, m.user_id, m.roster_name, p.handle)`, `handle` as today, `student_ref` = `m.user_id::text`.
   - `pseudonymous`: `user_id` = `null::uuid`, `roster_name` and `handle` = `app.pseudonym_for(cohort, m.user_id)`, `student_ref` = `app.pseudonym_for(cohort, m.user_id)`.
   Implement with `case v_res when 'per_student' then ... else ... end` expressions in the select list.
4. Re-issue the original grants (`revoke ... from public, anon; grant execute ... to authenticated;`) for both new signatures.

- [ ] **Step 4: Run to verify it passes.** `./supabase/tests/run_local.sh`
Expected: `OK: migrations + smoke test passed`

- [ ] **Step 5: Also fix the portal privacy copy.** In `docs/faculty/index.html:262` region, update the privacy note to state: "What this page shows follows the class reporting policy: per student, pseudonymous, or aggregate only. Changes to the policy apply immediately to every report." (No em-dashes.)

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260821000200_reporting_policy.sql supabase/tests/smoke.sql docs/faculty/index.html
git commit -m "Reporting policy enforced server-side at a single chokepoint"
```

---

### Task 5: Analytics RPCs (at-risk, drill-down, engagement)

**Files:**
- Create: `supabase/migrations/20260821000300_analytics_rpcs.sql`
- Test: append to `supabase/tests/smoke.sql`

**Interfaces:**
- Consumes: `app.effective_resolution`, `app.pseudonym_for`, `app.identity_label` (Task 4), `app.is_cohort_ta_or_above` (Task 3), read models `user_domain_readiness`, `user_objective_readiness`, `events`, `live_answers`, `mock_attempts`, `domains(id, name)`, `objectives(id, title)` (verify the objectives title column name against `20260710000100`; if it is `name`, use `name`).
- Produces (the web app's analytics contract):
  - `public.cohort_engagement_trend(p_cohort uuid, p_days int default 28) returns table (day date, active_students bigint, answers bigint)`
  - `public.at_risk_students(p_cohort uuid, p_threshold real default 0.6) returns table (student_ref text, display_name text, overall_readiness real, weakest_domain_id smallint, weakest_domain_name text, weakest_readiness real, last_active timestamptz, answers_14d bigint)`
  - `public.student_drilldown(p_cohort uuid, p_student_ref text) returns jsonb` with keys `identity`, `domains`, `weak_objectives`, `activity`, `live_sessions`, `mocks`, `suggestions`.

- [ ] **Step 1: Write the failing test.** Append to `supabase/tests/smoke.sql`:

```sql
-- ── Analytics RPCs ──────────────────────────────────────────────────────────
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts limit 1);
  v_trend int;
  r record;
  v_dd jsonb;
begin
  select count(*) into v_trend
    from public.cohort_engagement_trend(v_cohort, 14);
  if v_trend <> 14 then
    raise exception 'trend must return one row per day, got %', v_trend;
  end if;

  -- s1 answered earlier in this script; with threshold 1.01 every student
  -- is at risk, so rows must come back with identity and weakest domain.
  select * into r from public.at_risk_students(v_cohort, 1.01) limit 1;
  if r.student_ref is null or r.display_name is null then
    raise exception 'at_risk_students returned incomplete rows';
  end if;

  v_dd := public.student_drilldown(v_cohort, r.student_ref);
  if v_dd -> 'identity' is null or v_dd -> 'domains' is null
     or v_dd -> 'activity' is null or v_dd -> 'suggestions' is null then
    raise exception 'student_drilldown missing keys: %', v_dd;
  end if;
end $$;

-- Policy applies: pseudonymous refs resolve, aggregate_only refuses.
select public.set_reporting_policy(
  (select id from public.cohorts limit 1), 'pseudonymous', 'pseudonym');
do $$
declare
  v_cohort uuid := (select id from public.cohorts limit 1);
  r record;
  v_dd jsonb;
begin
  select * into r from public.at_risk_students(v_cohort, 1.01) limit 1;
  if r.student_ref not like 'Student %' then
    raise exception 'pseudonymous at-risk rows must use pseudonyms';
  end if;
  v_dd := public.student_drilldown(v_cohort, r.student_ref);
  if v_dd -> 'identity' ->> 'display_name' <> r.student_ref then
    raise exception 'drilldown must resolve pseudonym refs';
  end if;
end $$;
select public.set_reporting_policy(
  (select id from public.cohorts limit 1), 'aggregate_only', 'pseudonym');
do $$
declare v_cohort uuid := (select id from public.cohorts limit 1);
begin
  begin
    perform * from public.at_risk_students(v_cohort, 1.01);
    raise exception 'aggregate_only cohort listed at-risk students';
  exception when others then
    if sqlerrm like '%listed at-risk%' then raise; end if;
  end;
end $$;
select public.set_reporting_policy(
  (select id from public.cohorts limit 1), 'per_student', 'roster');
```

- [ ] **Step 2: Run to verify it fails.** `./supabase/tests/run_local.sh`
Expected: FAIL (`cohort_engagement_trend` does not exist).

- [ ] **Step 3: Write the migration** `supabase/migrations/20260821000300_analytics_rpcs.sql`:

```sql
-- Educator analytics: engagement trend (aggregate, ta-or-above), at-risk
-- list and per-student drill-down (policy-gated via app.effective_resolution).
-- One semantic layer: every surface renders these RPCs, nothing recomputes.

create function public.cohort_engagement_trend(
  p_cohort uuid, p_days int default 28
) returns table (day date, active_students bigint, answers bigint)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  if p_days not between 7 and 120 then
    raise exception 'days must be between 7 and 120';
  end if;
  return query
    select d::date as day,
           count(distinct e.user_id) as active_students,
           count(e.event_id) as answers
      from generate_series(
             current_date - (p_days - 1), current_date, interval '1 day') d
      left join public.events e
        on e.cohort_id = p_cohort and e.type = 'answer'
       and e.server_ts >= d and e.server_ts < d + interval '1 day'
     group by d::date
     order by d::date;
end;
$$;
revoke all on function public.cohort_engagement_trend(uuid, int) from public, anon;
grant execute on function public.cohort_engagement_trend(uuid, int) to authenticated;

create function public.at_risk_students(
  p_cohort uuid, p_threshold real default 0.6
) returns table (
  student_ref text, display_name text, overall_readiness real,
  weakest_domain_id smallint, weakest_domain_name text,
  weakest_readiness real, last_active timestamptz, answers_14d bigint
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare v_res text;
begin
  v_res := app.effective_resolution(p_cohort);
  if v_res = 'aggregate_only' then
    raise exception 'this class reports aggregate data only';
  end if;
  return query
    with base as (
      select m.user_id, m.roster_name, p.handle,
             coalesce(avg(r.readiness), 0)::real as overall
        from public.cohort_members m
        join public.profiles p on p.id = m.user_id
        left join public.user_domain_readiness r
          on r.user_id = m.user_id
       where m.cohort_id = p_cohort and m.role = 'student'
       group by m.user_id, m.roster_name, p.handle
    ), weakest as (
      select b.user_id, r.domain_id, d.name, r.readiness,
             row_number() over (partition by b.user_id
                                order by r.readiness asc nulls first) as rn
        from base b
        left join public.user_domain_readiness r on r.user_id = b.user_id
        left join public.domains d on d.id = r.domain_id
    ), act as (
      select b.user_id, max(e.server_ts) as last_active,
             count(e.event_id) filter (
               where e.type = 'answer'
                 and e.server_ts > now() - interval '14 days') as a14
        from base b
        left join public.events e
          on e.user_id = b.user_id and e.cohort_id = p_cohort
       group by b.user_id
    )
    select case when v_res = 'per_student' then b.user_id::text
                else app.pseudonym_for(p_cohort, b.user_id) end,
           case when v_res = 'per_student'
                then app.identity_label(p_cohort, b.user_id, b.roster_name, b.handle)
                else app.pseudonym_for(p_cohort, b.user_id) end,
           b.overall,
           w.domain_id, w.name, w.readiness,
           act.last_active, coalesce(act.a14, 0)
      from base b
      left join weakest w on w.user_id = b.user_id and w.rn = 1
      left join act on act.user_id = b.user_id
     where b.overall < p_threshold
     order by b.overall asc, act.last_active asc nulls first;
end;
$$;
revoke all on function public.at_risk_students(uuid, real) from public, anon;
grant execute on function public.at_risk_students(uuid, real) to authenticated;
```

And `student_drilldown` in the same file:

```sql
create function public.student_drilldown(p_cohort uuid, p_student_ref text)
returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_res text;
  v_target uuid;
  v_roster text;
  v_handle text;
  v_identity jsonb;
  v_domains jsonb;
  v_objectives jsonb;
  v_activity jsonb;
  v_live jsonb;
  v_mocks jsonb;
  v_suggestions jsonb;
begin
  v_res := app.effective_resolution(p_cohort);
  if v_res = 'aggregate_only' then
    raise exception 'this class reports aggregate data only';
  end if;

  if v_res = 'per_student' then
    v_target := p_student_ref::uuid;
    if not exists (select 1 from public.cohort_members
                    where cohort_id = p_cohort and user_id = v_target
                      and role = 'student') then
      raise exception 'no such student in this class';
    end if;
  else
    select m.user_id into v_target
      from public.cohort_members m
     where m.cohort_id = p_cohort and m.role = 'student'
       and app.pseudonym_for(p_cohort, m.user_id) = p_student_ref;
    if v_target is null then
      raise exception 'no such student in this class';
    end if;
  end if;

  select m.roster_name, p.handle into v_roster, v_handle
    from public.cohort_members m join public.profiles p on p.id = m.user_id
   where m.cohort_id = p_cohort and m.user_id = v_target;

  v_identity := jsonb_build_object(
    'student_ref', p_student_ref,
    'display_name', case when v_res = 'per_student'
      then app.identity_label(p_cohort, v_target, v_roster, v_handle)
      else app.pseudonym_for(p_cohort, v_target) end);

  select coalesce(jsonb_agg(jsonb_build_object(
           'domain_id', d.id, 'name', d.name,
           'readiness', r.readiness, 'accuracy', r.accuracy)
           order by r.readiness asc nulls first), '[]'::jsonb)
    into v_domains
    from public.domains d
    left join public.user_domain_readiness r
      on r.user_id = v_target and r.domain_id = d.id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'objective_id', w.id, 'title', w.title,
           'readiness', w.readiness)
           order by w.readiness asc), '[]'::jsonb)
    into v_objectives
    from (
      select o.id, o.title, r.readiness
        from public.user_objective_readiness r
        join public.objectives o on o.id = r.objective_id
       where r.user_id = v_target and r.readiness < 0.6
       order by r.readiness asc
       limit 5) w;

  select jsonb_build_object(
           'last_active', max(e.server_ts),
           'answers_7d', count(e.event_id) filter (
             where e.type = 'answer'
               and e.server_ts > now() - interval '7 days'),
           'answers_28d', count(e.event_id) filter (
             where e.type = 'answer'
               and e.server_ts > now() - interval '28 days'),
           'answers_total', count(e.event_id) filter (where e.type = 'answer'),
           'accuracy', coalesce(avg(e.correct::int) filter (
             where e.type = 'answer' and e.correct is not null), 0))
    into v_activity
    from public.events e
   where e.user_id = v_target and e.cohort_id = p_cohort;

  select coalesce(jsonb_agg(jsonb_build_object(
           'session_id', s.id, 'title', s.title, 'held_at', s.created_at,
           'correct', t.correct_count, 'answered', t.answered)
           order by s.created_at desc), '[]'::jsonb)
    into v_live
    from (
      select a.session_id,
             count(*) filter (where a.correct) as correct_count,
             count(*) as answered
        from public.live_answers a
        join public.live_sessions ls on ls.id = a.session_id
       where a.user_id = v_target and ls.cohort_id = p_cohort
       group by a.session_id) t
    join public.live_sessions s on s.id = t.session_id;

  select jsonb_build_object(
           'completed', count(*),
           'best_score', max(a.score))
    into v_mocks
    from public.mock_attempts a
   where a.user_id = v_target and a.cohort_id = p_cohort
     and a.completed_at is not null;

  -- Rule-based next steps: the two weakest domains under 0.6, plus an
  -- inactivity nudge. Plain sentences the UI can render or prefill.
  select coalesce(jsonb_agg(s.txt), '[]'::jsonb) into v_suggestions
    from (
      select format('Assign weak-area practice on %s (readiness %s%%).',
                    d.name, round(coalesce(r.readiness, 0) * 100)) as txt
        from public.user_domain_readiness r
        join public.domains d on d.id = r.domain_id
       where r.user_id = v_target and coalesce(r.readiness, 0) < 0.6
       order by r.readiness asc nulls first
       limit 2) s;
  if (v_activity ->> 'last_active') is null
     or (v_activity ->> 'last_active')::timestamptz < now() - interval '7 days' then
    v_suggestions := v_suggestions ||
      to_jsonb('Nudge this student: no practice in the last 7 days.'::text);
  end if;

  return jsonb_build_object(
    'identity', v_identity, 'domains', v_domains,
    'weak_objectives', v_objectives, 'activity', v_activity,
    'live_sessions', v_live, 'mocks', v_mocks,
    'suggestions', v_suggestions);
end;
$$;
revoke all on function public.student_drilldown(uuid, text) from public, anon;
grant execute on function public.student_drilldown(uuid, text) to authenticated;
```

Before finalizing, verify the `objectives` column names against `20260710000100_cohort_attribution_student_scope.sql` (the table lives there or in `20260704000200_content.sql`); if the display column is `name` not `title`, adjust the two references and the produced JSON key stays `title`.

- [ ] **Step 4: Run to verify it passes.** `./supabase/tests/run_local.sh`
Expected: `OK: migrations + smoke test passed`

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260821000300_analytics_rpcs.sql supabase/tests/smoke.sql
git commit -m "Analytics RPCs: engagement trend, at-risk list, student drill-down"
```

---

### Task 6: Guest browser join for live sessions

**Files:**
- Create: `supabase/migrations/20260821000400_guest_live_join.sql`
- Test: append to `supabase/tests/smoke.sql`

**Interfaces:**
- Consumes: live-session tables and RPCs (`20260723000100`, presence from `20260723000200`, finalizer from `20260724000100:256`).
- Produces: `public.join_live_session_guest(p_code text, p_display_name text) returns jsonb` (same shape as `join_live_session`), `app.is_session_participant(p_session uuid) returns boolean`, `profiles.is_guest boolean`, `live_participants.is_guest boolean` + `display_name text`, `live_sessions.allow_guests boolean`, `app.purge_live_guest_data() returns void`. The web join page calls `join_live_session_guest` after `supabase.auth.signInAnonymously()`.

- [ ] **Step 1: Write the failing test.** Append to `supabase/tests/smoke.sql`:

```sql
-- ── Guest live join ─────────────────────────────────────────────────────────
-- Faculty starts a session; a guest (anonymous auth) joins by code,
-- answers, appears on the scoreboard by display name, and is excluded
-- from cohort analytics at finalize.
\set g_uid '''00000000-0000-0000-0000-0000000000b1'''
reset role;
insert into auth.users (id, email) values (:g_uid, null);
set role authenticated;

set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts limit 1);
  v_session jsonb;
begin
  v_session := public.create_live_session(
    v_cohort, 'Guest-joinable quiz',
    (select jsonb_agg(id) from (select id from public.questions
       where cohort_id is null and review_status = 'published'
       limit 2) q), 20);
  perform set_config('app.test_session',
                     v_session ->> 'id', false);
  perform set_config('app.test_join_code',
                     v_session ->> 'join_code', false);
  perform public.advance_live_session((v_session ->> 'id')::uuid);
end $$;

set app.test_uid = :g_uid;
do $$
declare
  v_join jsonb;
  v_session uuid := current_setting('app.test_session')::uuid;
  v_q jsonb;
begin
  v_join := public.join_live_session_guest(
    current_setting('app.test_join_code'), 'Alex R');
  if (v_join ->> 'id')::uuid <> v_session then
    raise exception 'guest join returned wrong session';
  end if;
  v_q := public.get_live_question(v_session);
  perform public.submit_live_answer(
    v_session, (v_q -> 'question' ->> 'id')::uuid, 'b');
end $$;

-- Guest is on the scoreboard by display name (faculty view during question).
set app.test_uid = :f_uid;
do $$
declare v_session uuid := current_setting('app.test_session')::uuid;
begin
  if not exists (select 1 from public.live_scoreboard(v_session)
                  where handle = 'Alex R') then
    raise exception 'guest missing from scoreboard by display name';
  end if;
  -- End the session (advance through remaining phases).
  perform public.advance_live_session(v_session); -- reveal
  perform public.advance_live_session(v_session); -- question 2
  perform public.advance_live_session(v_session); -- reveal
  perform public.advance_live_session(v_session); -- ended + finalize
end $$;

-- Finalize must NOT have folded the guest into cohort events/leaderboard.
reset role;
do $$
begin
  if exists (select 1 from public.events
              where user_id = '00000000-0000-0000-0000-0000000000b1') then
    raise exception 'guest answers leaked into cohort events';
  end if;
  if exists (select 1 from public.leaderboard
              where user_id = '00000000-0000-0000-0000-0000000000b1') then
    raise exception 'guest leaked into leaderboard';
  end if;
end $$;

-- Purge removes stale guest data.
update public.live_participants set joined_at = now() - interval '60 days'
 where is_guest;
update public.live_answers a set created_at = now() - interval '60 days'
  from public.live_participants lp
 where lp.session_id = a.session_id and lp.user_id = a.user_id and lp.is_guest;
select app.purge_live_guest_data();
do $$
begin
  if exists (select 1 from public.live_participants where is_guest) then
    raise exception 'purge left guest participants behind';
  end if;
  if exists (select 1 from public.profiles
              where id = '00000000-0000-0000-0000-0000000000b1') then
    raise exception 'purge left the guest profile behind';
  end if;
end $$;
set role authenticated;
```

- [ ] **Step 2: Run to verify it fails.** `./supabase/tests/run_local.sh`
Expected: FAIL (`join_live_session_guest` does not exist).

- [ ] **Step 3: Write the migration** `supabase/migrations/20260821000400_guest_live_join.sql`:

```sql
-- Browser guest join for live sessions: a student with no account joins by
-- code from any browser (Supabase anonymous auth supplies auth.uid()).
-- Guests answer through the same server-graded path, appear on the session
-- scoreboard by a self-typed display name, and never enter cohort
-- analytics. Guest rows purge on a schedule (data minimization).

alter table public.profiles
  add column is_guest boolean not null default false;

alter table public.live_sessions
  add column allow_guests boolean not null default true;

alter table public.live_participants
  add column is_guest boolean not null default false,
  add column display_name text
    check (display_name is null or length(trim(display_name)) between 2 and 40);

create function app.is_session_participant(p_session uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.live_participants
    where session_id = p_session and user_id = auth.uid());
$$;

-- Guests can read their session row (Realtime phase updates).
create policy live_sessions_select_participants on public.live_sessions
  for select to authenticated using (app.is_session_participant(id));

create function public.join_live_session_guest(
  p_code text, p_display_name text
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s record;
  v_user uuid := auth.uid();
  v_name text := nullif(trim(coalesce(p_display_name, '')), '');
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if v_name is null or length(v_name) < 2 then
    raise exception 'enter a display name (2 to 40 characters)';
  end if;
  select * into s from public.live_sessions
   where join_code = upper(trim(p_code)) and status <> 'ended';
  if not found then raise exception 'invalid or ended session code'; end if;
  if not s.allow_guests and not app.is_cohort_member(s.cohort_id) then
    raise exception 'this session is limited to class members';
  end if;

  -- Guests get a minimal profile row (FK target only; not a member of
  -- anything). Handle is derived, unique, and purged with the guest.
  insert into public.profiles (id, handle, is_guest)
  values (v_user, 'g_' || substr(md5(v_user::text), 1, 8), true)
  on conflict (id) do nothing;

  insert into public.live_participants (session_id, user_id, is_guest, display_name)
  values (s.id, v_user, not app.is_cohort_member(s.cohort_id), v_name)
  on conflict (session_id, user_id) do update
    set display_name = excluded.display_name;

  return jsonb_build_object(
    'id', s.id, 'title', s.title, 'status', s.status,
    'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds);
end;
$$;
revoke all on function public.join_live_session_guest(text, text) from public, anon;
grant execute on function public.join_live_session_guest(text, text) to authenticated;
```

Then, in the same file:

1. Recreate `get_live_question`, `submit_live_answer`, `live_reveal`, and `live_scoreboard` (bodies verbatim from `20260723000100_live_sessions.sql:224,250,296,327`, with Task 3's ta-or-above edits where that task already touched the same function), changing each membership gate from `if not app.is_cohort_member(s.cohort_id)` to `if not (app.is_cohort_member(s.cohort_id) or app.is_session_participant(p_session))`.
2. In `live_scoreboard` additionally join presence for guest names: `left join public.live_participants lp on lp.session_id = p_session and lp.user_id = t.user_id` and select `coalesce(lp.display_name, p.handle)` as the `handle` column.
3. Recreate `app.finalize_live_session_scoring` (body verbatim from `20260724000100_admin_history_rollups_scoring.sql:256`) adding to its answer-selecting query: `and not exists (select 1 from public.live_participants lp where lp.session_id = a.session_id and lp.user_id = a.user_id and lp.is_guest)`.
4. Add the purge function and guarded cron schedule:

```sql
create function app.purge_live_guest_data() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  delete from public.live_answers a
   using public.live_participants lp,
         public.live_sessions s
   where lp.session_id = a.session_id and lp.user_id = a.user_id
     and lp.is_guest and s.id = a.session_id
     and a.created_at < now() - make_interval(days => coalesce(
           (select c.raw_retention_days from public.cohorts c
             where c.id = s.cohort_id), 30));
  delete from public.live_participants lp
   using public.live_sessions s
   where lp.is_guest and s.id = lp.session_id
     and lp.joined_at < now() - make_interval(days => coalesce(
           (select c.raw_retention_days from public.cohorts c
             where c.id = s.cohort_id), 30));
  delete from public.profiles p
   where p.is_guest
     and not exists (select 1 from public.live_participants lp
                      where lp.user_id = p.id);
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('purge-live-guests', '17 6 * * *',
      'select app.purge_live_guest_data()');
  end if;
end $$;
```

Match the cron-guard idiom used in `20260726000100_push_washington_cron.sql`; if that file guards differently (for example checking `cron.job` for an existing entry), mirror it exactly.

- [ ] **Step 4: Run to verify it passes.** `./supabase/tests/run_local.sh`
Expected: `OK: migrations + smoke test passed`

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260821000400_guest_live_join.sql supabase/tests/smoke.sql
git commit -m "Live sessions: guest browser join with purge and analytics exclusion"
```

---

### Task 7: Founder handoff for hosted apply

**Files:**
- Modify: `docs/audit/08-hosted-schema-verification.md` (still untracked)

- [ ] **Step 1: Extend the Task 1 report** with the four new migrations in apply order (after the pre-existing gap list), each with a one-line risk note: roles (additive + gate widenings), reporting policy (recreates two report RPCs; portal keeps working via appended column), analytics (new RPCs only), guest join (recreates four student RPCs and the finalizer; adds cron job).

- [ ] **Step 2: Summarize for the founder in the session**: apply list, order, and the reminder that `20260710000200` must precede `20260821000300` on hosted. Hosted applies remain manual and founder-approved.

---

## Backlog captured (not in this plan)

- Move the web app from GitHub Pages to politiface.app (domain, DNS, Supabase auth redirect URLs and allowed origins, redirects). After Sept 20.
- Plan B: the React web app (`web/`), typed contract generation and CI drift check, dashboard surfaces, live runner, join page UI, axe/Playwright testing, VPAT pass.
- Org-admin surfaces; per-student assignments; SSO/LTI (Epic 8).
