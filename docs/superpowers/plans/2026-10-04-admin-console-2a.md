# Admin Console 2a Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Gotham-style admin console at `politiface.app/app/#/admin`, for the founder and Dawood only, that shows everything happening in the system (live sessions, onboarding funnel, people, classes, sessions, a problem log, an audit log), lets them grant or revoke instructor access and manage invites, and replaces the legacy `/faculty` admin tab.

**Architecture:** One migration adds `app.admin_audit`, `app.ops_events` (problem log, 90-day retention), a public `log_ops_event` write RPC, and admin-gated read/write RPCs (`app.is_admin`, which holds exactly the two founder accounts). The web console gains a lazy-loaded `web/src/admin/` module with its own dark theme, Cmd-K palette, home, three-pane records, invites, and audit pages. Web and iOS clients report problems through a fire-and-forget logger.

**Tech Stack:** Supabase Postgres (plpgsql security-definer RPCs, RLS, pg_cron), React 19 + TanStack Router (hash history, `lazyRouteComponent`) + TanStack Query + Tailwind v4, Vitest + Testing Library + vitest-axe, Flutter 3.22 (supabase_flutter, package_info_plus).

**Spec:** `docs/superpowers/specs/2026-10-04-admin-console-design.md`

## Global Constraints

- Access: only accounts in `app.admins` (the founder and Dawood). Every admin RPC starts with `if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;`. Both admins see all data including student emails. No UI to add admins.
- Every RPC is `security definer set search_path = public, app, pg_temp`, with explicit `revoke all ... from public, anon; grant execute ... to authenticated;` (except `log_ops_event`, which anon may call).
- Problem log `kind` allow-list: `signin_send_failed`, `signin_verify_failed`, `join_refused`, `client_error`, `app_seen`. `client` allow-list: `web`, `ios`. Email kept only on `signin_*` rows, lowercased and trimmed. 90-day retention. Never answer content, never IP addresses.
- No em-dashes in any copy, SQL comment, or doc. All web copy for the console lives in `web/src/admin/strings.ts`.
- Gotham palette (scoped to `.admin-root`): bg `#0b0e13`, panel `#0f141b`, line `#1e2632`, text `#c7d0dc`, muted `#8a96a8`, strong `#e6edf5`, ok `#22c55e`, warn `#f59e0b`, fail `#ef4444`, info `#60a5fa`; monospaced font stack `ui-monospace, SFMono-Regular, Menlo, monospace`. Body text contrast at least 4.5:1 on bg.
- Logging never blocks or breaks a user flow: every logger call is fire-and-forget and swallows its own errors.
- Migrations are applied to production by the founder (agent production writes are blocked). Everything must pass `./supabase/tests/run_local.sh` first. `web/src/lib/database.types.ts` entries for new RPCs are added by hand in generator format, then regenerated after the founder applies (final task).
- Spec deviation recorded here: the person record shows a practice summary (answers and accuracy, last 30 days) instead of a readiness breakdown.

## File map

- Create `supabase/migrations/20261004000200_admin_console.sql` (built across Tasks 1 to 4).
- Modify `supabase/tests/smoke.sql` (admin console block at the end).
- Create `web/src/lib/opsLog.ts`; modify `web/src/auth/EmailCodeForm.tsx`, `web/src/routes/JoinPage.tsx`, `web/src/routes/router.tsx`, `web/src/auth/SessionProvider.tsx`, `web/vite.config.ts`, `web/src/globals.d.ts` (new).
- Create `web/src/admin/`: `strings.ts`, `adminApi.ts`, `admin.css`, `AdminLayout.tsx`, `CommandPalette.tsx`, `Timeline.tsx`, `ThreePane.tsx`, `AdminHome.tsx`, `SearchPage.tsx`, `PersonPage.tsx`, `ClassRecordPage.tsx`, `SessionRecordPage.tsx`, `InvitesPage.tsx`, `AuditPage.tsx`, and tests next to them.
- Modify `web/src/lib/api.ts` (`useAmAdmin`), `web/src/routes/Layout.tsx` (Console link), `web/src/lib/database.types.ts`.
- Create `app/lib/core/ops/ops_log.dart`; modify `app/lib/core/sync/sign_in_sheet.dart`, `app/lib/features/live/data/live_session_api.dart`, `app/lib/main.dart`; tests in `app/test/core/ops/`.
- Modify `docs/faculty/index.html` (Admin tab becomes a link to the console).

---

### Task 1: Audit log and problem log (schema, write RPC, purge, smoke)

**Files:**
- Create: `supabase/migrations/20261004000200_admin_console.sql`
- Modify: `supabase/tests/smoke.sql` (append before the final `reset role;` / `select 'SMOKE TEST PASSED' as result;`)

**Interfaces:**
- Produces (SQL):
  - `app.admin_audit` table; `app.audit(p_action text, p_user uuid default null, p_cohort uuid default null, p_session uuid default null, p_details jsonb default '{}')` (writes a row with `actor = auth.uid()`).
  - `app.ops_events` table.
  - `public.log_ops_event(p_kind text, p_client text, p_code text default null, p_detail jsonb default null, p_app_version text default null, p_email text default null) returns void` (anon + authenticated).
  - `app.purge_ops_events() returns void` (deletes rows older than 90 days), scheduled daily when pg_cron exists.

- [ ] **Step 1: Write the failing smoke block**

Append before the final lines of `supabase/tests/smoke.sql`:

```sql
-- ── Admin console 2a (20261004000200) ──────────────────────────────────────
-- Problem log: validation, email only on sign-in kinds, user_id from the
-- session, per-minute cap, app_seen deduped per day.
set app.test_uid = :s1_uid;
do $$
declare n int;
begin
  perform public.log_ops_event('join_refused', 'web', 'invalid or ended session code',
    '{"route": "#/join"}', 'web-2026-10-04', 'leak@example.edu');
  if exists (select 1 from app.ops_events where kind = 'join_refused' and email is not null) then
    raise exception 'FAIL: email stored on a non-sign-in event';
  end if;
  if not exists (select 1 from app.ops_events where kind = 'join_refused'
                  and user_id = auth.uid()) then
    raise exception 'FAIL: join_refused not attributed to the caller';
  end if;
  begin
    perform public.log_ops_event('made_up_kind', 'web');
    raise exception 'FAIL: unknown kind accepted';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.log_ops_event('client_error', 'android');
    raise exception 'FAIL: unknown client accepted';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.log_ops_event('client_error', 'web', null,
      jsonb_build_object('m', repeat('x', 3000)));
    raise exception 'FAIL: oversized detail accepted';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  for n in 1..40 loop
    perform public.log_ops_event('client_error', 'web', 'boom');
  end loop;
  select count(*) into n from app.ops_events
   where kind = 'client_error' and user_id = auth.uid();
  if n <> 30 then raise exception 'FAIL: per-minute cap not 30 (got %)', n; end if;
  perform public.log_ops_event('app_seen', 'ios', null, null, '1.3.2 (33)');
  perform public.log_ops_event('app_seen', 'ios', null, null, '1.3.2 (33)');
  select count(*) into n from app.ops_events
   where kind = 'app_seen' and user_id = auth.uid();
  if n <> 1 then raise exception 'FAIL: app_seen not deduped per day (got %)', n; end if;
end $$;

-- A signed-out failed sign-in keeps the typed email, lowercased.
set role anon;
set app.test_uid = '';
do $$
begin
  perform public.log_ops_event('signin_send_failed', 'web', '429',
    '{"status": 429}', null, '  Maria.Lopez@MyMDC.net ');
end $$;
reset role;
do $$
begin
  if not exists (select 1 from app.ops_events
                  where kind = 'signin_send_failed' and email = 'maria.lopez@mymdc.net'
                    and user_id is null) then
    raise exception 'FAIL: failed sign-in email not stored lowercased';
  end if;
  -- Purge: rows older than 90 days go, newer stay.
  insert into app.ops_events (kind, client, created_at)
  values ('client_error', 'web', now() - interval '91 days');
  perform app.purge_ops_events();
  if exists (select 1 from app.ops_events where created_at < now() - interval '90 days') then
    raise exception 'FAIL: purge left rows older than 90 days';
  end if;
  if not exists (select 1 from app.ops_events where email = 'maria.lopez@mymdc.net') then
    raise exception 'FAIL: purge removed a fresh row';
  end if;
end $$;
set role authenticated;
```

- [ ] **Step 2: Run to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.log_ops_event(...) does not exist`.

- [ ] **Step 3: Write the migration (part 1)**

Create `supabase/migrations/20261004000200_admin_console.sql`:

```sql
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
  created_at  timestamptz not null default now()
);
create index ops_events_created_idx on app.ops_events (created_at desc);
create index ops_events_user_idx on app.ops_events (user_id, created_at desc);
create index ops_events_email_idx on app.ops_events (email, created_at desc)
  where email is not null;
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
  v_email text;
  v_recent int;
begin
  if p_kind not in ('signin_send_failed', 'signin_verify_failed',
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

  select count(*) into v_recent from app.ops_events
   where kind = p_kind and created_at > now() - interval '1 minute'
     and ((v_user is not null and user_id = v_user)
          or (v_user is null and email = v_email));
  if v_recent >= 30 then return; end if;

  if p_kind = 'app_seen' then
    if v_user is null then return; end if;
    if exists (select 1 from app.ops_events
                where kind = 'app_seen' and user_id = v_user
                  and client = p_client
                  and created_at >= date_trunc('day', now())) then
      return;
    end if;
  end if;

  insert into app.ops_events (user_id, email, kind, code, detail, client, app_version)
  values (v_user, v_email, p_kind, left(p_code, 80), coalesce(p_detail, '{}'::jsonb),
          p_client, left(p_app_version, 40));
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
```

- [ ] **Step 4: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -3`
Expected: `OK: migrations + smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261004000200_admin_console.sql supabase/tests/smoke.sql
git commit -m "Admin console: audit log and problem log"
```

---

### Task 2: Admin home, activity stream, search (RPCs, smoke)

**Files:**
- Modify: `supabase/migrations/20261004000200_admin_console.sql` (append)
- Modify: `supabase/tests/smoke.sql` (append to the admin console block)

**Interfaces:**
- Consumes: Task 1 tables.
- Produces (SQL):
  - `public.admin_home() returns jsonb` with keys `totals` `{people, students, faculty, classes, answered_live_7d}`, `live_now[]` `{session_id, title, cohort_id, class, professor, status, index, total, participants, created_at}`, `pending_requests` (int), `funnel[]` `{cohort_id, name, term, members, students, answered_live, practiced_7d}`, `attention[]` `{kind, severity, title, cohort_id?}`, `health` `{run_at, ok, failures}` or null.
  - `public.admin_activity(p_since timestamptz) returns table (at timestamptz, kind text, severity text, title text, user_id uuid, cohort_id uuid, session_id uuid)`, newest first, max 100.
  - `public.admin_search(p_q text) returns table (kind text, id uuid, title text, subtitle text)`, kind in `person|class|session`, max 25.

- [ ] **Step 1: Write the failing smoke block**

Append to the admin console block in `supabase/tests/smoke.sql`:

```sql
-- Admin read RPCs: refused for students and plain faculty, allowed for an
-- admin (f_uid is in app.admins earlier in this file).
set app.test_uid = :s1_uid;
do $$
begin
  begin
    perform public.admin_home();
    raise exception 'FAIL: student read admin_home';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform * from public.admin_search('Civics');
    raise exception 'FAIL: student searched as admin';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
set app.test_uid = :p1_prof;   -- verified faculty, not an admin
do $$
begin
  begin
    perform * from public.admin_activity(now() - interval '1 day');
    raise exception 'FAIL: non-admin faculty read the activity stream';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

set app.test_uid = :f_uid;
do $$
declare h jsonb;
begin
  h := public.admin_home();
  if (h -> 'totals' ->> 'classes')::int < 1 then
    raise exception 'FAIL: admin_home totals missing classes: %', h -> 'totals';
  end if;
  if jsonb_typeof(h -> 'funnel') <> 'array' or jsonb_typeof(h -> 'live_now') <> 'array'
     or jsonb_typeof(h -> 'attention') <> 'array' then
    raise exception 'FAIL: admin_home shape wrong: %', h;
  end if;
  if not exists (select 1 from jsonb_array_elements(h -> 'funnel') f
                  where f ->> 'name' = 'Civics Section A') then
    raise exception 'FAIL: funnel missing the smoke class';
  end if;
  if not exists (select 1 from public.admin_activity(now() - interval '1 day')
                  where kind = 'class_join') then
    raise exception 'FAIL: activity stream missing class joins';
  end if;
  if not exists (select 1 from public.admin_activity(now() - interval '1 day')
                  where kind = 'problem' and severity = 'fail') then
    raise exception 'FAIL: activity stream missing problem-log rows';
  end if;
  if not exists (select 1 from public.admin_search('webstudent@') where kind = 'person') then
    raise exception 'FAIL: search by email found no person';
  end if;
  if not exists (select 1 from public.admin_search('Maria') where kind = 'person') then
    raise exception 'FAIL: search by roster name found no person';
  end if;
  if not exists (select 1 from public.admin_search('Civics Section') where kind = 'class') then
    raise exception 'FAIL: search found no class';
  end if;
  if exists (select 1 from public.admin_search('x')) then
    raise exception 'FAIL: one-character search returned results';
  end if;
end $$;
```

- [ ] **Step 2: Run to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.admin_home() does not exist`.

- [ ] **Step 3: Append the SQL**

Append to `supabase/migrations/20261004000200_admin_console.sql`:

```sql
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
             p.handle || ' created an account', p.id, null::uuid, null::uuid
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
             lp.user_id, s.cohort_id, s.id
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
             p.handle || ' messaged ' || c.name, a.author, a.cohort_id, null::uuid
        from public.class_announcements a
        join public.cohorts c on c.id = a.cohort_id
        left join public.profiles p on p.id = a.author
       where a.created_at > p_since
      union all
      select r.created_at, 'request', 'warn',
             p.handle || ' requested instructor access', r.user_id, null::uuid, null::uuid
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
  v_like text;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if length(v_q) < 2 then return; end if;
  v_like := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return query
    select * from (
      select 'person'::text, p.id,
             coalesce(r.names, p.handle),
             coalesce(u.email, '') || ' · ' || p.handle
        from public.profiles p
        join auth.users u on u.id = p.id
        left join lateral (
          select string_agg(distinct m.roster_name, ', ') names
            from public.cohort_members m
           where m.user_id = p.id and m.roster_name is not null) r on true
       where not p.is_guest
         and (u.email ilike v_like or p.handle ilike v_like or r.names ilike v_like)
      union all
      select 'class', c.id, c.name,
             coalesce(c.term, '') || ' · code ' || c.join_code
        from public.cohorts c
       where c.name ilike v_like or c.join_code = upper(v_q)
      union all
      select 'session', s.id, s.title,
             c.name || ' · ' || s.status || ' · code ' || s.join_code
        from public.live_sessions s join public.cohorts c on c.id = s.cohort_id
       where s.title ilike v_like or s.join_code = upper(v_q)
    ) t(kind, id, title, subtitle)
    order by t.kind, t.title
    limit 25;
end;
$$;
revoke all on function public.admin_search(text) from public, anon;
grant execute on function public.admin_search(text) to authenticated;
```

- [ ] **Step 4: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -3`
Expected: `OK: migrations + smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261004000200_admin_console.sql supabase/tests/smoke.sql
git commit -m "Admin console: home, activity stream, search RPCs"
```

---

### Task 3: Person, class, and session records with timelines (RPCs, smoke)

**Files:**
- Modify: `supabase/migrations/20261004000200_admin_console.sql` (append)
- Modify: `supabase/tests/smoke.sql` (append)
- Modify: `supabase/tests/shim_auth.sql` (the plain-Postgres auth stand-in lacks columns production has)

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces (SQL), every timeline entry is `{at, kind, title, detail, severity}` (`severity` in `info|ok|warn|fail`), newest first, max 300:
  - `public.admin_person(p_user uuid) returns jsonb`: `{identity:{user_id,email,handle,school,created_at,last_sign_in_at,is_admin,is_faculty,is_guest}, memberships:[{cohort_id,name,term,role,roster_name,joined_at}], sessions:[{session_id,title,cohort_id,class,joined_at,answered,correct}], devices:[{user_agent,created_at,refreshed_at}], push_devices:int, app_versions:{ios?,web?}, practice:{answers_30d,correct_30d}, timeline:[...]}`. Writes audit `view_person`.
  - `public.admin_class(p_cohort uuid) returns jsonb`: `{facts:{cohort_id,name,term,join_code,owner,created_at,reporting_resolution,is_demo}, members:[{user_id,handle,email,role,roster_name,joined_at,last_active}], sessions:[{session_id,title,status,created_at,ended_at,participants,answers}], funnel:{members,students,answered_live,practiced_7d}, timeline:[...]}`.
  - `public.admin_session(p_session uuid) returns jsonb`: `{facts:{session_id,title,cohort_id,class,professor,status,index,total,question_seconds,join_code,allow_guests,created_at,ended_at}, participants:[{user_id,name,is_guest,joined_at,answered,correct}], questions:[{position,question_id,stem,answered,correct_rate}], timeline:[...]}`.
  - `public.admin_console_open() returns void`: audit `console_open`, at most once per 10 minutes per admin.

- [ ] **Step 0: Extend the auth shim to match production**

Append to `supabase/tests/shim_auth.sql` (production Supabase already has these; the shim only mimics them for local tests):

```sql
-- Columns and table the admin console reads (production has them).
alter table auth.users
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists last_sign_in_at timestamptz;
create table if not exists auth.sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz,
  refreshed_at timestamp,
  user_agent   text,
  ip           inet
);
```

- [ ] **Step 1: Write the failing smoke block**

Append to the admin console block:

```sql
-- Records: refused for non-admins; shapes; view_person audited; timelines
-- carry the problem log.
set app.test_uid = :s1_uid;
do $$
begin
  begin
    perform public.admin_person(auth.uid());
    raise exception 'FAIL: student opened a person record';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

set app.test_uid = :f_uid;
do $$
declare
  r jsonb;
  v_cohort uuid := (select id from public.cohorts where name = 'Civics Section A');
  v_session uuid := current_setting('app.p1_session')::uuid;
begin
  r := public.admin_person('00000000-0000-0000-0000-000000000001'::uuid);
  if r -> 'identity' ->> 'email' <> 's1@example.edu' then
    raise exception 'FAIL: person identity wrong: %', r -> 'identity';
  end if;
  if jsonb_array_length(r -> 'memberships') < 1 then
    raise exception 'FAIL: person memberships missing';
  end if;
  if not exists (select 1 from jsonb_array_elements(r -> 'timeline') t
                  where t ->> 'kind' = 'problem' and t ->> 'severity' = 'fail') then
    raise exception 'FAIL: person timeline missing the problem log';
  end if;
  r := public.admin_class(v_cohort);
  if r -> 'facts' ->> 'name' <> 'Civics Section A'
     or jsonb_array_length(r -> 'members') < 2 then
    raise exception 'FAIL: class record wrong: %', r -> 'facts';
  end if;
  r := public.admin_session(v_session);
  if r -> 'facts' ->> 'title' <> 'Members only quiz'
     or jsonb_array_length(r -> 'participants') < 1
     or jsonb_array_length(r -> 'questions') < 1 then
    raise exception 'FAIL: session record wrong: %', r -> 'facts';
  end if;
  perform public.admin_console_open();
  perform public.admin_console_open();
end $$;
reset role;
do $$
begin
  if not exists (select 1 from app.admin_audit
                  where action = 'view_person'
                    and target_user = '00000000-0000-0000-0000-000000000001') then
    raise exception 'FAIL: view_person not audited';
  end if;
  if (select count(*) from app.admin_audit where action = 'console_open') <> 1 then
    raise exception 'FAIL: console_open not throttled to once per 10 minutes';
  end if;
end $$;
set role authenticated;
```

(psql variables do not interpolate inside `do $$`, hence the literal: it is `s1_uid`.)

- [ ] **Step 2: Run to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.admin_person(uuid) does not exist`.

- [ ] **Step 3: Append the SQL**

Append to the migration:

```sql
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
```

- [ ] **Step 4: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -3`
Expected: `OK: migrations + smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261004000200_admin_console.sql supabase/tests/smoke.sql
git commit -m "Admin console: person, class, session records with timelines"
```

---

### Task 4: Instructor access, invites, audit list (write RPCs, smoke)

**Files:**
- Modify: `supabase/migrations/20261004000200_admin_console.sql` (append)
- Modify: `supabase/tests/smoke.sql` (append)

**Interfaces:**
- Produces (SQL):
  - `public.admin_set_faculty_audited(p_user uuid, p_verified boolean) returns void` (audits `faculty_granted` / `faculty_revoked`).
  - `public.admin_list_invites_v2() returns table (code text, note text, minted_by_handle text, recipient_email text, uses int, max_uses int, created_at timestamptz, expires_at timestamptz, revoked_at timestamptz, status text)`, status in `active|used|expired|revoked`, newest first.
  - `public.admin_mint_invite(p_note text default null, p_recipient_email text default null) returns text` (audits `invite_minted`).
  - `public.admin_revoke_invite(p_code text) returns void` (audits `invite_revoked`).
  - `public.admin_audit_list(p_action text default null, p_limit int default 200) returns table (id bigint, created_at timestamptz, actor_handle text, action text, target_user uuid, target_label text, target_cohort uuid, target_session uuid, details jsonb)`.

- [ ] **Step 1: Write the failing smoke block**

Append:

```sql
-- Admin writes: refused for non-admins; audited for admins.
set app.test_uid = :p1_prof;
do $$
begin
  begin
    perform public.admin_set_faculty_audited(
      '00000000-0000-0000-0000-000000000002'::uuid, true);
    raise exception 'FAIL: non-admin granted instructor access';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.admin_mint_invite('x', null);
    raise exception 'FAIL: non-admin used the admin mint';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

set app.test_uid = :f_uid;
do $$
declare v_code text;
begin
  perform public.admin_set_faculty_audited(
    '00000000-0000-0000-0000-000000000002'::uuid, true);
  if not exists (select 1 from app.verified_faculty
                  where user_id = '00000000-0000-0000-0000-000000000002') then
    raise exception 'FAIL: grant did not verify';
  end if;
  perform public.admin_set_faculty_audited(
    '00000000-0000-0000-0000-000000000002'::uuid, false);
  if exists (select 1 from app.verified_faculty
              where user_id = '00000000-0000-0000-0000-000000000002') then
    raise exception 'FAIL: revoke did not unverify';
  end if;
  v_code := public.admin_mint_invite('For a smoke prof', 'prof@example.edu');
  if not exists (select 1 from public.admin_list_invites_v2()
                  where code = v_code and status = 'active') then
    raise exception 'FAIL: minted invite not listed active';
  end if;
  perform public.admin_revoke_invite(v_code);
  if not exists (select 1 from public.admin_list_invites_v2()
                  where code = v_code and status = 'revoked') then
    raise exception 'FAIL: revoked invite not listed revoked';
  end if;
  if (select count(*) from public.admin_audit_list(null, 50)
       where action in ('faculty_granted', 'faculty_revoked',
                        'invite_minted', 'invite_revoked')) <> 4 then
    raise exception 'FAIL: admin writes not all audited';
  end if;
end $$;
```

- [ ] **Step 2: Run to verify it fails**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -5`
Expected: FAIL with `function public.admin_set_faculty_audited(uuid, boolean) does not exist`.

- [ ] **Step 3: Append the SQL**

```sql
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
    perform app.audit('faculty_granted', p_user);
  else
    delete from app.verified_faculty where user_id = p_user;
    perform app.audit('faculty_revoked', p_user);
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
    jsonb_build_object('code', v_code, 'recipient', p_recipient_email));
  return v_code;
end;
$$;
revoke all on function public.admin_mint_invite(text, text) from public, anon;
grant execute on function public.admin_mint_invite(text, text) to authenticated;

create function public.admin_revoke_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
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
```

- [ ] **Step 4: Run the smoke test**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -3`
Expected: `OK: migrations + smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261004000200_admin_console.sql supabase/tests/smoke.sql
git commit -m "Admin console: audited instructor access, invites, audit list"
```

---

### Task 5: Web problem logging

**Files:**
- Create: `web/src/lib/opsLog.ts`, `web/src/lib/opsLog.test.ts`
- Modify: `web/vite.config.ts`, `web/src/globals.d.ts` (new), `web/src/auth/EmailCodeForm.tsx`, `web/src/routes/JoinPage.tsx`, `web/src/routes/router.tsx`, `web/src/auth/SessionProvider.tsx`, `web/src/lib/database.types.ts`
- Test: `web/src/lib/opsLog.test.ts`, `web/src/auth/emailCodeForm.test.tsx` (extend)

**Interfaces:**
- Produces: `logOpsEvent(kind: OpsKind, opts?: { code?: string; detail?: Record<string, unknown>; email?: string }): void` where `type OpsKind = 'signin_send_failed' | 'signin_verify_failed' | 'join_refused' | 'client_error' | 'app_seen'`. Fire-and-forget; never throws.
- Build id: `__APP_BUILD__` (string, `web-YYYY-MM-DD`), injected by Vite.

- [ ] **Step 1: Write the failing tests**

Create `web/src/lib/opsLog.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const rpc = vi.hoisted(() => vi.fn(async () => ({ error: null })))
vi.mock('./supabase', () => ({ supabase: { rpc } }))

import { logOpsEvent } from './opsLog'

describe('logOpsEvent', () => {
  beforeEach(() => rpc.mockClear())

  it('sends kind, client web, build, and the details', async () => {
    logOpsEvent('signin_send_failed', {
      code: '429',
      detail: { status: 429 },
      email: 'maria@mymdc.net',
    })
    await Promise.resolve()
    expect(rpc).toHaveBeenCalledWith('log_ops_event', {
      p_kind: 'signin_send_failed',
      p_client: 'web',
      p_code: '429',
      p_detail: { status: 429 },
      p_app_version: expect.stringMatching(/^web-/),
      p_email: 'maria@mymdc.net',
    })
  })

  it('never throws, even when the call fails', async () => {
    rpc.mockRejectedValueOnce(new Error('offline'))
    expect(() => logOpsEvent('client_error', { code: 'x' })).not.toThrow()
    await Promise.resolve()
  })
})
```

In `web/src/auth/emailCodeForm.test.tsx`, add `vi.mock('../lib/opsLog', () => ({ logOpsEvent }))` with a hoisted `logOpsEvent = vi.fn()`, and a test:

```tsx
  it('reports a failed code send to the problem log with the typed email', async () => {
    signInWithOtp.mockResolvedValueOnce({ error: { status: 429, code: 'over_email_send_rate_limit', message: 'x' } } as never)
    render(<EmailCodeForm />)
    await userEvent.type(screen.getByLabelText(/email/i), 'Maria@MyMDC.net')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    expect(logOpsEvent).toHaveBeenCalledWith('signin_send_failed', {
      code: 'over_email_send_rate_limit',
      detail: { status: 429 },
      email: 'Maria@MyMDC.net',
    })
  })
```

(Add `logOpsEvent` to the existing `vi.hoisted` block in that file.)

- [ ] **Step 2: Run to verify they fail**

Run: `cd web && npx vitest run src/lib/opsLog.test.ts src/auth/emailCodeForm.test.tsx`
Expected: FAIL (module `./opsLog` not found).

- [ ] **Step 3: Implement**

`web/vite.config.ts`: add to the config object

```ts
  define: {
    __APP_BUILD__: JSON.stringify(`web-${new Date().toISOString().slice(0, 10)}`),
  },
```

Declare it in a new `web/src/globals.d.ts`:

```ts
declare const __APP_BUILD__: string
```

Create `web/src/lib/opsLog.ts`:

```ts
// Problem log (admin console 2a): fire-and-forget reports of what went
// wrong for a user, so the founders can see it on the person's timeline.
// Never blocks or breaks a flow; failures to log are swallowed.
import { supabase } from './supabase'

export type OpsKind =
  | 'signin_send_failed'
  | 'signin_verify_failed'
  | 'join_refused'
  | 'client_error'
  | 'app_seen'

const BUILD = typeof __APP_BUILD__ === 'string' ? __APP_BUILD__ : 'web-dev'

export function logOpsEvent(
  kind: OpsKind,
  opts: { code?: string; detail?: Record<string, unknown>; email?: string } = {},
): void {
  try {
    void Promise.resolve(
      supabase.rpc('log_ops_event' as never, {
        p_kind: kind,
        p_client: 'web',
        p_code: opts.code ?? null,
        p_detail: opts.detail ?? null,
        p_app_version: BUILD,
        p_email: opts.email ?? null,
      } as never),
    ).catch(() => undefined)
  } catch {
    // never let logging break the caller
  }
}
```

`web/src/auth/EmailCodeForm.tsx`: import `logOpsEvent`; in `sendCode`, where `error` is set (both the rate-limited and the generic branch), call before setting the message:

```ts
      logOpsEvent('signin_send_failed', {
        code: String(error.code ?? error.status ?? 'unknown'),
        detail: { status: error.status ?? null },
        email: email.trim(),
      })
```

and in `verify` on error:

```ts
      logOpsEvent('signin_verify_failed', {
        code: String(error.code ?? error.status ?? 'unknown'),
        detail: { status: error.status ?? null },
        email: email.trim(),
      })
```

In both `catch` blocks (thrown errors), log the same kind with `code: 'thrown'`.

`web/src/routes/JoinPage.tsx`: in `StudentJoin`'s `run` catch and `GuestJoin`'s submit catch, call `logOpsEvent('join_refused', { code: (err as Error).message.slice(0, 80), detail: { session_code: code } })`.

`web/src/routes/router.tsx`: change `RouteError` to accept `{ error }: { error: unknown }` and log once on mount:

```tsx
function RouteError({ error }: { error: unknown }) {
  useEffect(() => {
    logOpsEvent('client_error', {
      code: 'route_error',
      detail: {
        route: window.location.hash.slice(0, 120),
        message: String((error as Error)?.message ?? error).slice(0, 300),
      },
    })
  }, [error])
  // existing JSX unchanged
```

(import `useEffect` from `react` and `logOpsEvent` from `../lib/opsLog`).

`web/src/auth/SessionProvider.tsx`: in the `onAuthStateChange` callback, after `ensureProfile`, add `logOpsEvent('app_seen')` for non-anonymous sessions (the server keeps one row per user per day).

`web/src/lib/database.types.ts`: add in generator format, alphabetically:

```ts
      log_ops_event: {
        Args: {
          p_app_version?: string
          p_client: string
          p_code?: string
          p_detail?: Json
          p_email?: string
          p_kind: string
        }
        Returns: undefined
      }
```

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run && npm run typecheck && npm run lint`
Expected: all pass; typecheck clean; no new lint errors. Update any existing test whose mocks of `../lib/opsLog`-importing modules now break (add `vi.mock('../lib/opsLog', () => ({ logOpsEvent: vi.fn() }))` where a test renders `EmailCodeForm`, `JoinPage`, or `SessionProvider` with a mocked supabase that lacks `rpc`).

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/opsLog.ts web/src/lib/opsLog.test.ts web/vite.config.ts web/src/globals.d.ts web/src/auth web/src/routes/JoinPage.tsx web/src/routes/router.tsx web/src/lib/database.types.ts
git commit -m "Web: report sign-in failures, refused joins, and errors to the problem log"
```

---

### Task 6: Console shell, theme, routes, Console link, palette

**Files:**
- Create: `web/src/admin/strings.ts`, `web/src/admin/admin.css`, `web/src/admin/adminApi.ts`, `web/src/admin/AdminLayout.tsx`, `web/src/admin/CommandPalette.tsx`, `web/src/admin/adminLayout.test.tsx`
- Modify: `web/src/routes/router.tsx`, `web/src/routes/Layout.tsx`, `web/src/lib/api.ts`, `web/src/lib/database.types.ts`

**Interfaces:**
- Produces:
  - `useAmAdmin()` in `web/src/lib/api.ts` (query key `['am-admin']`, calls `am_admin`).
  - `web/src/admin/adminApi.ts`: types `AdminHome`, `ActivityRow`, `SearchHit`, `PersonRecord`, `ClassRecord`, `SessionRecord`, `TimelineEntry`, `InviteRow`, `AuditRow` matching Tasks 2 to 4; hooks `useAdminHome()`, `useAdminActivity()`, `useAdminSearch(q: string)`, `useAdminPerson(id)`, `useAdminClass(id)`, `useAdminSession(id)`, `useAdminInvites()`, `useAdminAudit()`, mutations `useSetFaculty()`, `useMintInvite()`, `useRevokeInvite()`, and `consoleOpen()`.
  - Routes: `#/admin` (home), `#/admin/search`, `#/admin/people/$userId`, `#/admin/classes/$cohortId`, `#/admin/sessions/$sessionId`, `#/admin/invites`, `#/admin/audit`. Page components are created in Tasks 7 to 9; this task registers routes with `lazyRouteComponent` pointing at modules that Task 6 creates as minimal placeholders exporting the named components (each renders its `A.titles.*` heading), which later tasks replace.
  - `AdminLayout` renders `<Outlet />` inside the shell for admins, a "Not available" notice for everyone else.

- [ ] **Step 1: Write the failing test**

Create `web/src/admin/adminLayout.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const s = vi.hoisted(() => ({ admin: true as boolean | undefined, navigate: vi.fn() }))
vi.mock('../lib/api', () => ({
  useAmAdmin: () => ({ data: s.admin, isPending: s.admin === undefined }),
}))
vi.mock('./adminApi', () => ({
  consoleOpen: vi.fn(async () => undefined),
  useAdminHome: () => ({ data: { live_now: [{ session_id: 's1' }] } }),
  useAdminSearch: (q: string) => ({
    data: q.length >= 2
      ? [{ kind: 'person', id: 'u1', title: 'Maria Lopez', subtitle: 'maria@mymdc.net' }]
      : [],
  }),
}))
vi.mock('@tanstack/react-router', () => ({
  Outlet: () => <p>page body</p>,
  Link: ({ to, children, ...rest }: { to: string; children: React.ReactNode }) => (
    <a href={`#${to}`} {...rest}>{children}</a>
  ),
  useNavigate: () => s.navigate,
}))

import { AdminLayout } from './AdminLayout'

describe('AdminLayout', () => {
  it('admins get the console shell and the page', () => {
    s.admin = true
    render(<AdminLayout />)
    expect(screen.getByText('POLITIFACE // CONSOLE')).toBeInTheDocument()
    expect(screen.getByText('page body')).toBeInTheDocument()
    expect(screen.getByText(/LIVE 1/)).toBeInTheDocument()
  })

  it('everyone else gets a notice, not the console', () => {
    s.admin = false
    render(<AdminLayout />)
    expect(screen.getByText(/not available/i)).toBeInTheDocument()
    expect(screen.queryByText('page body')).toBeNull()
  })

  it('Cmd-K opens search and Enter opens the first hit', async () => {
    s.admin = true
    render(<AdminLayout />)
    await userEvent.keyboard('{Meta>}k{/Meta}')
    await userEvent.type(screen.getByRole('combobox'), 'Maria')
    expect(screen.getByText('Maria Lopez')).toBeInTheDocument()
    await userEvent.keyboard('{Enter}')
    expect(s.navigate).toHaveBeenCalledWith({ to: '/admin/people/u1' })
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/admin/adminLayout.test.tsx`
Expected: FAIL (module `./AdminLayout` not found).

- [ ] **Step 3: Implement**

`web/src/admin/strings.ts`:

```ts
// Console copy. House rule: no em-dashes.
export const A = {
  brand: 'POLITIFACE // CONSOLE',
  notAvailable: 'The console is not available for this account.',
  live: (n: number) => `LIVE ${n}`,
  searchPlaceholder: 'Search people, classes, sessions, codes',
  searchHint: 'Cmd-K',
  noHits: 'No matches.',
  nav: { home: 'Home', search: 'Search', invites: 'Invites', audit: 'Audit' },
  titles: {
    home: 'Overview',
    search: 'Search',
    person: 'Person',
    klass: 'Class',
    session: 'Session',
    invites: 'Invites',
    audit: 'Audit log',
  },
  comingIn2b: 'Coming in 2b',
  loading: 'Loading',
}
```

`web/src/admin/admin.css`:

```css
/* Gotham palette, scoped to the console only. */
.admin-root {
  --a-bg: #0b0e13;
  --a-panel: #0f141b;
  --a-line: #1e2632;
  --a-text: #c7d0dc;
  --a-muted: #8a96a8;
  --a-strong: #e6edf5;
  --a-ok: #22c55e;
  --a-warn: #f59e0b;
  --a-fail: #ef4444;
  --a-info: #60a5fa;
  background: var(--a-bg);
  color: var(--a-text);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 12px;
  line-height: 1.45;
  min-height: 100vh;
}
.admin-root a { color: var(--a-info); }
.admin-root a:hover { text-decoration: underline; }
.admin-panel { border: 1px solid var(--a-line); background: var(--a-panel); }
.admin-label { color: var(--a-muted); font-size: 10px; letter-spacing: 0.08em; text-transform: uppercase; }
.admin-strong { color: var(--a-strong); }
.sev-ok { color: var(--a-ok); }
.sev-warn { color: var(--a-warn); }
.sev-fail { color: var(--a-fail); }
.sev-info { color: var(--a-info); }
.admin-root :focus-visible { outline: 2px solid var(--a-info); outline-offset: 2px; }
```

`web/src/admin/adminApi.ts`:

```ts
// Admin console data. All reads and writes are admin-only RPCs; the
// server refuses anyone not in app.admins.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { friendlyMessage } from '../lib/api'

async function call<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn as never, args as never)
  if (error) throw new Error(friendlyMessage(error))
  return data as T
}

export type Severity = 'info' | 'ok' | 'warn' | 'fail'
export type TimelineEntry = {
  at: string
  kind: string
  title: string
  detail: unknown
  severity: Severity
}
export type LiveNow = {
  session_id: string
  title: string
  cohort_id: string
  class: string
  professor: string | null
  status: string
  index: number
  total: number
  participants: number
  created_at: string
}
export type FunnelRow = {
  cohort_id: string
  name: string
  term: string | null
  members: number
  students: number
  answered_live: number
  practiced_7d: number
}
export type AttentionItem = {
  kind: string
  severity: Severity
  title: string
  cohort_id?: string
}
export type AdminHome = {
  totals: {
    people: number
    students: number
    faculty: number
    classes: number
    answered_live_7d: number
  }
  live_now: LiveNow[]
  pending_requests: number
  funnel: FunnelRow[]
  attention: AttentionItem[]
  health: { run_at: string; ok: boolean; failures: unknown } | null
}
export type ActivityRow = {
  at: string
  kind: string
  severity: Severity
  title: string
  user_id: string | null
  cohort_id: string | null
  session_id: string | null
}
export type SearchHit = {
  kind: 'person' | 'class' | 'session'
  id: string
  title: string
  subtitle: string
}
export type PersonRecord = {
  identity: {
    user_id: string
    email: string | null
    handle: string
    school: string | null
    created_at: string
    last_sign_in_at: string | null
    is_admin: boolean
    is_faculty: boolean
    is_guest: boolean
  }
  memberships: {
    cohort_id: string
    name: string
    term: string | null
    role: string
    roster_name: string | null
    joined_at: string
  }[]
  sessions: {
    session_id: string
    title: string
    cohort_id: string
    class: string
    joined_at: string
    answered: number
    correct: number
  }[]
  devices: { user_agent: string | null; created_at: string; refreshed_at: string | null }[]
  push_devices: number
  app_versions: { ios?: string; web?: string }
  practice: { answers_30d: number; correct_30d: number }
  timeline: TimelineEntry[]
}
export type ClassRecord = {
  facts: {
    cohort_id: string
    name: string
    term: string | null
    join_code: string
    owner: string | null
    created_at: string
    reporting_resolution: string | null
    is_demo: boolean
  }
  members: {
    user_id: string
    handle: string | null
    email: string | null
    role: string
    roster_name: string | null
    joined_at: string
    last_active: string | null
  }[]
  sessions: {
    session_id: string
    title: string
    status: string
    created_at: string
    ended_at: string | null
    participants: number
    answers: number
  }[]
  funnel: { members: number; students: number; answered_live: number; practiced_7d: number }
  timeline: TimelineEntry[]
}
export type SessionRecord = {
  facts: {
    session_id: string
    title: string
    cohort_id: string
    class: string
    professor: string | null
    status: string
    index: number
    total: number
    question_seconds: number
    join_code: string
    allow_guests: boolean
    created_at: string
    ended_at: string | null
  }
  participants: {
    user_id: string
    name: string
    is_guest: boolean
    joined_at: string
    answered: number
    correct: number
  }[]
  questions: {
    position: number
    question_id: string
    stem: string
    answered: number
    correct_rate: number | null
  }[]
  timeline: TimelineEntry[]
}
export type InviteRow = {
  code: string
  note: string | null
  minted_by_handle: string | null
  recipient_email: string | null
  uses: number
  max_uses: number
  created_at: string
  expires_at: string
  revoked_at: string | null
  status: 'active' | 'used' | 'expired' | 'revoked'
}
export type AuditRow = {
  id: number
  created_at: string
  actor_handle: string | null
  action: string
  target_user: string | null
  target_label: string | null
  target_cohort: string | null
  target_session: string | null
  details: unknown
}

export const consoleOpen = () => call<void>('admin_console_open')

export const useAdminHome = () =>
  useQuery({
    queryKey: ['admin', 'home'],
    queryFn: () => call<AdminHome>('admin_home'),
    refetchInterval: 15_000,
  })
export const useAdminActivity = () =>
  useQuery({
    queryKey: ['admin', 'activity'],
    queryFn: () =>
      call<ActivityRow[]>('admin_activity', {
        p_since: new Date(Date.now() - 24 * 3600_000).toISOString(),
      }),
    refetchInterval: 5_000,
  })
export const useAdminSearch = (q: string) =>
  useQuery({
    queryKey: ['admin', 'search', q],
    queryFn: () => call<SearchHit[]>('admin_search', { p_q: q }),
    enabled: q.trim().length >= 2,
  })
export const useAdminPerson = (id: string) =>
  useQuery({
    queryKey: ['admin', 'person', id],
    queryFn: () => call<PersonRecord>('admin_person', { p_user: id }),
  })
export const useAdminClass = (id: string) =>
  useQuery({
    queryKey: ['admin', 'class', id],
    queryFn: () => call<ClassRecord>('admin_class', { p_cohort: id }),
  })
export const useAdminSession = (id: string) =>
  useQuery({
    queryKey: ['admin', 'session', id],
    queryFn: () => call<SessionRecord>('admin_session', { p_session: id }),
    refetchInterval: 5_000,
  })
export const useAdminInvites = () =>
  useQuery({
    queryKey: ['admin', 'invites'],
    queryFn: () => call<InviteRow[]>('admin_list_invites_v2'),
  })
export const useAdminAudit = () =>
  useQuery({
    queryKey: ['admin', 'audit'],
    queryFn: () => call<AuditRow[]>('admin_audit_list', { p_limit: 200 }),
  })

export const useSetFaculty = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { userId: string; verified: boolean }) =>
      call<void>('admin_set_faculty_audited', {
        p_user: a.userId,
        p_verified: a.verified,
      }),
    onSuccess: (_d, a) => void qc.invalidateQueries({ queryKey: ['admin', 'person', a.userId] }),
  })
}
export const useMintInvite = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { note: string; recipientEmail: string }) =>
      call<string>('admin_mint_invite', {
        p_note: a.note || null,
        p_recipient_email: a.recipientEmail || null,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['admin', 'invites'] }),
  })
}
export const useRevokeInvite = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (code: string) => call<void>('admin_revoke_invite', { p_code: code }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['admin', 'invites'] }),
  })
}
```

`web/src/admin/CommandPalette.tsx`:

```tsx
import { useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { useAdminSearch, type SearchHit } from './adminApi'
import { A } from './strings'

export function hitPath(h: SearchHit): string {
  if (h.kind === 'person') return `/admin/people/${h.id}`
  if (h.kind === 'class') return `/admin/classes/${h.id}`
  return `/admin/sessions/${h.id}`
}

/** Cmd-K / Ctrl-K: search everything, Enter opens the first hit. */
export function CommandPalette() {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const navigate = useNavigate()
  const hits = useAdminSearch(q).data ?? []

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setOpen(o => !o)
      }
      if (e.key === 'Escape') setOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const go = (h: SearchHit) => {
    setOpen(false)
    setQ('')
    void navigate({ to: hitPath(h) })
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex-1 border border-[var(--a-line)] px-2 py-1 text-left text-[var(--a-muted)]"
      >
        {A.searchHint} {A.searchPlaceholder}
      </button>
      {open ? (
        <div
          role="dialog"
          aria-label={A.titles.search}
          className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-24"
          onClick={() => setOpen(false)}
        >
          <div
            className="admin-panel w-[min(640px,92vw)] p-2"
            onClick={e => e.stopPropagation()}
          >
            <input
              role="combobox"
              aria-expanded={hits.length > 0}
              aria-label={A.searchPlaceholder}
              autoFocus
              value={q}
              onChange={e => setQ(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && hits[0]) go(hits[0])
              }}
              placeholder={A.searchPlaceholder}
              className="w-full border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1.5 text-[var(--a-strong)]"
            />
            <ul className="mt-2 max-h-80 overflow-y-auto">
              {q.trim().length >= 2 && hits.length === 0 ? (
                <li className="px-2 py-1 text-[var(--a-muted)]">{A.noHits}</li>
              ) : null}
              {hits.slice(0, 8).map(h => (
                <li key={`${h.kind}-${h.id}`}>
                  <button
                    type="button"
                    onClick={() => go(h)}
                    className="flex w-full gap-2 px-2 py-1 text-left hover:bg-[var(--a-line)]"
                  >
                    <span className="admin-label w-16">{h.kind}</span>
                    <span className="admin-strong">{h.title}</span>
                    <span className="text-[var(--a-muted)]">{h.subtitle}</span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>
      ) : null}
    </>
  )
}
```

`web/src/admin/AdminLayout.tsx`:

```tsx
import { useEffect } from 'react'
import { Link, Outlet } from '@tanstack/react-router'
import { useAmAdmin } from '../lib/api'
import { consoleOpen, useAdminHome } from './adminApi'
import { CommandPalette } from './CommandPalette'
import { A } from './strings'
import './admin.css'

const rail = [
  { to: '/admin', label: A.nav.home, glyph: '◉' },
  { to: '/admin/search', label: A.nav.search, glyph: '⌕' },
  { to: '/admin/invites', label: A.nav.invites, glyph: '✉' },
  { to: '/admin/audit', label: A.nav.audit, glyph: '▤' },
]

export function AdminLayout() {
  const admin = useAmAdmin()
  const home = useAdminHome()
  useEffect(() => {
    if (admin.data) void consoleOpen().catch(() => undefined)
  }, [admin.data])

  if (admin.isPending) return <div className="admin-root p-6">{A.loading}</div>
  if (!admin.data) {
    return (
      <div className="admin-root flex items-center justify-center p-6">
        <p>{A.notAvailable}</p>
      </div>
    )
  }
  const live = home.data?.live_now.length ?? 0
  return (
    <div className="admin-root flex flex-col">
      <header className="flex items-center gap-3 border-b border-[var(--a-line)] bg-[var(--a-panel)] px-3 py-2">
        <span className="admin-strong font-bold tracking-[0.12em]">{A.brand}</span>
        <CommandPalette />
        <span className={live > 0 ? 'sev-ok' : 'text-[var(--a-muted)]'}>● {A.live(live)}</span>
      </header>
      <div className="flex flex-1">
        <nav aria-label="Console" className="flex w-12 flex-col items-center gap-3 border-r border-[var(--a-line)] pt-3">
          {rail.map(r => (
            <Link key={r.to} to={r.to} title={r.label} aria-label={r.label} className="text-[var(--a-muted)]">
              <span aria-hidden="true">{r.glyph}</span>
            </Link>
          ))}
        </nav>
        <main className="flex-1 p-3">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
```

Placeholder page modules (replaced in Tasks 7 to 9), each exporting its named component rendering an `<h1 className="admin-strong">` with the matching `A.titles.*`:
`web/src/admin/AdminHome.tsx` (`AdminHome`), `SearchPage.tsx` (`SearchPage`), `PersonPage.tsx` (`PersonPage`), `ClassRecordPage.tsx` (`ClassRecordPage`), `SessionRecordPage.tsx` (`SessionRecordPage`), `InvitesPage.tsx` (`InvitesPage`), `AuditPage.tsx` (`AuditPage`).

`web/src/routes/router.tsx`: import `lazyRouteComponent` from `@tanstack/react-router` and `RequireAuth` from `../auth/RequireAuth`; add a route tree that is a child of `rootRoute` (outside the light `shellRoute`):

```tsx
const adminRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin',
  component: () => (
    <RequireAuth>
      <AdminShell />
    </RequireAuth>
  ),
})
const AdminShell = lazyRouteComponent(() => import('../admin/AdminLayout'), 'AdminLayout')
const adminHomeRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/',
  component: lazyRouteComponent(() => import('../admin/AdminHome'), 'AdminHome'),
})
const adminSearchRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/search',
  component: lazyRouteComponent(() => import('../admin/SearchPage'), 'SearchPage'),
})
const adminPersonRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/people/$userId',
  component: lazyRouteComponent(() => import('../admin/PersonPage'), 'PersonPage'),
})
const adminClassRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/classes/$cohortId',
  component: lazyRouteComponent(() => import('../admin/ClassRecordPage'), 'ClassRecordPage'),
})
const adminSessionRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/sessions/$sessionId',
  component: lazyRouteComponent(() => import('../admin/SessionRecordPage'), 'SessionRecordPage'),
})
const adminInvitesRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/invites',
  component: lazyRouteComponent(() => import('../admin/InvitesPage'), 'InvitesPage'),
})
const adminAuditRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/audit',
  component: lazyRouteComponent(() => import('../admin/AuditPage'), 'AuditPage'),
})
```

Add `adminRoute.addChildren([adminHomeRoute, adminSearchRoute, adminPersonRoute, adminClassRoute, adminSessionRoute, adminInvitesRoute, adminAuditRoute])` to `rootRoute.addChildren([...])`. Define `AdminShell` before `adminRoute` (move the const above it).

`web/src/lib/api.ts`: add near the other query hooks:

```ts
export const useAmAdmin = () =>
  useQuery({
    queryKey: ['am-admin'],
    queryFn: () => rpc<boolean>('am_admin'),
    staleTime: 5 * 60_000,
  })
```

`web/src/routes/Layout.tsx`: in `Nav`, add after the "Your classes" link, only when `useAmAdmin().data` is true:

```tsx
{isAdmin ? (
  <Link to="/admin" className="text-sm text-slate-600 hover:text-slate-900">
    Console
  </Link>
) : null}
```

(with `const isAdmin = useAmAdmin().data === true` and the `S`-less literal moved to `S.common.console = 'Console'` in `web/src/lib/strings.ts`).

`web/src/lib/database.types.ts`: add generator-format entries (alphabetical) for every RPC in Tasks 1 to 4: `admin_activity`, `admin_audit_list`, `admin_class`, `admin_console_open`, `admin_home`, `admin_list_invites_v2`, `admin_mint_invite`, `admin_person`, `admin_revoke_invite`, `admin_search`, `admin_session`, `admin_set_faculty_audited` (Args from the SQL signatures, defaults optional; table-returning functions as `Returns: { ... }[]`; jsonb as `Json`; void as `undefined`; no-arg as `Args: never`).

Update every existing test that mocks `../lib/api` and renders `Layout` or the router to include `useAmAdmin: () => ({ data: false })`.

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run && npm run typecheck && npm run lint && npm run build`
Expected: all pass; the build output lists separate chunks for the admin modules (check `dist/assets` has more than one `.js` file).

- [ ] **Step 5: Commit**

```bash
git add web/src/admin web/src/routes/router.tsx web/src/routes/Layout.tsx web/src/lib/api.ts web/src/lib/strings.ts web/src/lib/database.types.ts web/src
git commit -m "Admin console: Gotham shell, lazy routes, Console link, Cmd-K search"
```

---

### Task 7: Console home and search page

**Files:**
- Replace: `web/src/admin/AdminHome.tsx`, `web/src/admin/SearchPage.tsx`
- Create: `web/src/admin/adminHome.test.tsx`

**Interfaces:**
- Consumes: `useAdminHome`, `useAdminActivity`, `useAdminSearch`, types, `hitPath` (Task 6).
- Produces: `AdminHome()`, `SearchPage()`.

- [ ] **Step 1: Write the failing test**

Create `web/src/admin/adminHome.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'

vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, params, children }: { to: string; params?: Record<string, string>; children: React.ReactNode }) => (
    <a href={`#${Object.entries(params ?? {}).reduce((p, [k, v]) => p.replace(`$${k}`, v), to)}`}>{children}</a>
  ),
  useSearch: () => ({ q: 'maria' }),
}))
vi.mock('./adminApi', () => ({
  useAdminHome: () => ({
    data: {
      totals: { people: 297, students: 212, faculty: 3, classes: 9, answered_live_7d: 171 },
      live_now: [{ session_id: 's1', title: 'Week 3 review', cohort_id: 'c1', class: 'Section A', professor: 'Purcell Demo', status: 'question', index: 3, total: 8, participants: 38, created_at: '2026-10-04T15:02:00Z' }],
      pending_requests: 2,
      funnel: [{ cohort_id: 'c1', name: 'Section A', term: '2026F', members: 41, students: 40, answered_live: 38, practiced_7d: 22 }],
      attention: [{ kind: 'signin_failures', severity: 'fail', title: '14 sign-in failures in the last hour' }],
      health: { run_at: '2026-10-04T06:07:00Z', ok: true, failures: [] },
    },
    isPending: false,
    error: null,
  }),
  useAdminActivity: () => ({
    data: [
      { at: '2026-10-04T15:06:12Z', kind: 'live_join', severity: 'ok', title: 'Maria Lopez joined live: Week 3 review', user_id: 'u1', cohort_id: 'c1', session_id: 's1' },
      { at: '2026-10-04T15:05:40Z', kind: 'problem', severity: 'fail', title: 'signin send failed: 429 (maria@mymdc.net)', user_id: null, cohort_id: null, session_id: null },
    ],
    isPending: false,
  }),
  useAdminSearch: () => ({ data: [{ kind: 'person', id: 'u1', title: 'Maria Lopez', subtitle: 'maria@mymdc.net · user_1' }], isPending: false }),
}))

import { AdminHome } from './AdminHome'
import { SearchPage } from './SearchPage'

describe('AdminHome', () => {
  it('shows totals, live now, funnel, attention, and the activity stream', () => {
    render(<AdminHome />)
    expect(screen.getByText('212')).toBeInTheDocument()
    expect(screen.getByText('Week 3 review')).toBeInTheDocument()
    expect(screen.getByText(/Q4\/8/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Section A' })).toHaveAttribute('href', '#/admin/classes/c1')
    expect(screen.getByText('14 sign-in failures in the last hour')).toHaveClass('sev-fail')
    expect(screen.getByText(/signin send failed/)).toBeInTheDocument()
    expect(screen.getByText('NOMINAL')).toBeInTheDocument()
  })
})

describe('SearchPage', () => {
  it('lists hits linking to their records', () => {
    render(<SearchPage />)
    expect(screen.getByRole('link', { name: /Maria Lopez/ })).toHaveAttribute('href', '#/admin/people/u1')
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/admin/adminHome.test.tsx`
Expected: FAIL (placeholders render only a heading).

- [ ] **Step 3: Implement**

`web/src/admin/AdminHome.tsx`:

```tsx
import { Link } from '@tanstack/react-router'
import { useAdminActivity, useAdminHome } from './adminApi'
import { A } from './strings'

const time = (iso: string) =>
  new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })

function Stat({ label, value, tone }: { label: string; value: string | number; tone?: string }) {
  return (
    <div className="admin-panel p-2">
      <div className="admin-label">{label}</div>
      <div className={`text-lg ${tone ?? 'admin-strong'}`}>{value}</div>
    </div>
  )
}

export function AdminHome() {
  const home = useAdminHome()
  const activity = useAdminActivity()
  if (home.isPending) return <p>{A.loading}</p>
  if (home.error || !home.data) return <p className="sev-fail">{home.error?.message}</p>
  const h = home.data
  const nominal = h.health?.ok !== false
  return (
    <div className="flex flex-col gap-2">
      <h1 className="sr-only">{A.titles.home}</h1>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-5">
        <Stat label="People" value={h.totals.people} />
        <Stat label="Students enrolled" value={h.totals.students} />
        <Stat label="Answered live (7d)" value={h.totals.answered_live_7d} />
        <Stat label="Pending requests" value={h.pending_requests} tone={h.pending_requests > 0 ? 'sev-warn' : undefined} />
        <Stat label="System" value={nominal ? 'NOMINAL' : 'CHECK'} tone={nominal ? 'sev-ok' : 'sev-fail'} />
      </div>
      <div className="grid gap-2 lg:grid-cols-[1.25fr_1fr]">
        <section className="admin-panel p-2" aria-label="Live now">
          <h2 className="admin-label mb-1">Live now</h2>
          {h.live_now.length === 0 ? <p className="text-[var(--a-muted)]">No live sessions.</p> : null}
          {h.live_now.map(s => (
            <div key={s.session_id} className="mb-1 border-l-2 border-[var(--a-ok)] pl-2">
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }} className="admin-strong">
                {s.title}
              </Link>{' '}
              · {s.class} · Q{s.index + 1}/{s.total} · {s.participants} in room
              <div className="text-[var(--a-muted)]">{s.professor} · started {time(s.created_at)}</div>
            </div>
          ))}
          <h2 className="admin-label mb-1 mt-3">Onboarding funnel</h2>
          <table className="w-full">
            <thead>
              <tr className="admin-label text-left">
                <th scope="col">Class</th><th scope="col">Members</th><th scope="col">Students</th>
                <th scope="col">Answered live</th><th scope="col">Practiced 7d</th>
              </tr>
            </thead>
            <tbody>
              {h.funnel.map(f => (
                <tr key={f.cohort_id} className="border-t border-[var(--a-line)]">
                  <td>
                    <Link to="/admin/classes/$cohortId" params={{ cohortId: f.cohort_id }}>{f.name}</Link>
                  </td>
                  <td>{f.members}</td><td>{f.students}</td><td>{f.answered_live}</td><td>{f.practiced_7d}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <div className="flex flex-col gap-2">
          <section className="admin-panel p-2" aria-label="Needs attention">
            <h2 className="admin-label mb-1">Needs attention</h2>
            {h.attention.length === 0 ? <p className="sev-ok">All clear.</p> : null}
            <ul>
              {h.attention.map((a, i) => (
                <li key={i} className={`sev-${a.severity}`}>{a.title}</li>
              ))}
            </ul>
          </section>
          <section className="admin-panel p-2" aria-label="Activity">
            <h2 className="admin-label mb-1">Activity</h2>
            <ol className="max-h-96 overflow-y-auto">
              {(activity.data ?? []).map((r, i) => (
                <li key={`${r.at}-${i}`}>
                  <span className="text-[var(--a-muted)]">{time(r.at)}</span>{' '}
                  <span className={`sev-${r.severity}`}>{r.kind.toUpperCase()}</span>{' '}
                  {r.user_id ? (
                    <Link to="/admin/people/$userId" params={{ userId: r.user_id }}>{r.title}</Link>
                  ) : (
                    <span>{r.title}</span>
                  )}
                </li>
              ))}
            </ol>
          </section>
        </div>
      </div>
    </div>
  )
}
```

`web/src/admin/SearchPage.tsx`:

```tsx
import { useState } from 'react'
import { Link } from '@tanstack/react-router'
import { useAdminSearch } from './adminApi'
import { hitPath } from './CommandPalette'
import { A } from './strings'

export function SearchPage() {
  const [q, setQ] = useState('')
  const hits = useAdminSearch(q).data ?? []
  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.search}</h1>
      <input
        aria-label={A.searchPlaceholder}
        placeholder={A.searchPlaceholder}
        value={q}
        onChange={e => setQ(e.target.value)}
        className="admin-panel px-2 py-1.5 text-[var(--a-strong)]"
      />
      <ul className="admin-panel p-2">
        {hits.map(h => (
          <li key={`${h.kind}-${h.id}`}>
            <Link to={hitPath(h)}>
              <span className="admin-label mr-2">{h.kind}</span>
              {h.title}
            </Link>{' '}
            <span className="text-[var(--a-muted)]">{h.subtitle}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

For the test's `SearchPage` hit to appear, the page must render hits even before typing when the mocked hook returns them (it does: the mock ignores `q`).

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run src/admin && npm run typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src/admin/AdminHome.tsx web/src/admin/SearchPage.tsx web/src/admin/adminHome.test.tsx
git commit -m "Admin console: home (live now, funnel, attention, activity) and search"
```

---

### Task 8: Three-pane records (person, class, session) with instructor access action

**Files:**
- Create: `web/src/admin/ThreePane.tsx`, `web/src/admin/Timeline.tsx`, `web/src/admin/records.test.tsx`
- Replace: `web/src/admin/PersonPage.tsx`, `web/src/admin/ClassRecordPage.tsx`, `web/src/admin/SessionRecordPage.tsx`

**Interfaces:**
- Consumes: `useAdminPerson`, `useAdminClass`, `useAdminSession`, `useSetFaculty`, types (Task 6).
- Produces: `ThreePane({ header, left, center, right })`, `Timeline({ entries })`, `PersonPage()`, `ClassRecordPage()`, `SessionRecordPage()` (route params via `useParams({ strict: false })`).

- [ ] **Step 1: Write the failing test**

Create `web/src/admin/records.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const m = vi.hoisted(() => ({ setFaculty: vi.fn() }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, params, children }: { to: string; params?: Record<string, string>; children: React.ReactNode }) => (
    <a href={`#${Object.entries(params ?? {}).reduce((p, [k, v]) => p.replace(`$${k}`, v), to)}`}>{children}</a>
  ),
  useParams: () => ({ userId: 'u1', cohortId: 'c1', sessionId: 's1' }),
}))
const timeline = [
  { at: '2026-10-04T11:06:00Z', kind: 'live_answers', title: '3 of 4 correct in Week 3 review', detail: null, severity: 'info' },
  { at: '2026-10-04T10:58:00Z', kind: 'problem', title: 'signin send failed: 429', detail: { status: 429 }, severity: 'fail' },
]
vi.mock('./adminApi', () => ({
  useAdminPerson: () => ({
    data: {
      identity: { user_id: 'u1', email: 'maria@mymdc.net', handle: 'user_1', school: null, created_at: '2026-09-29T00:00:00Z', last_sign_in_at: '2026-10-04T11:00:00Z', is_admin: false, is_faculty: false, is_guest: false },
      memberships: [{ cohort_id: 'c1', name: 'Section A', term: '2026F', role: 'student', roster_name: 'Maria Lopez', joined_at: '2026-10-04T11:01:00Z' }],
      sessions: [{ session_id: 's1', title: 'Week 3 review', cohort_id: 'c1', class: 'Section A', joined_at: '2026-10-04T11:02:00Z', answered: 4, correct: 3 }],
      devices: [{ user_agent: 'Dart/3.4 (dart:io)', created_at: '2026-10-04T11:00:00Z', refreshed_at: null }],
      push_devices: 1,
      app_versions: { ios: '1.3.2 (33)' },
      practice: { answers_30d: 17, correct_30d: 11 },
      timeline,
    },
    isPending: false,
    error: null,
  }),
  useAdminClass: () => ({
    data: {
      facts: { cohort_id: 'c1', name: 'Section A', term: '2026F', join_code: 'UHHT2B', owner: 'Purcell Demo', created_at: '2026-09-28T00:00:00Z', reporting_resolution: 'per_student', is_demo: false },
      members: [{ user_id: 'u1', handle: 'user_1', email: 'maria@mymdc.net', role: 'student', roster_name: 'Maria Lopez', joined_at: '2026-10-04T11:01:00Z', last_active: null }],
      sessions: [{ session_id: 's1', title: 'Week 3 review', status: 'ended', created_at: '2026-10-04T11:00:00Z', ended_at: '2026-10-04T11:20:00Z', participants: 38, answers: 140 }],
      funnel: { members: 41, students: 40, answered_live: 38, practiced_7d: 22 },
      timeline,
    },
    isPending: false,
    error: null,
  }),
  useAdminSession: () => ({
    data: {
      facts: { session_id: 's1', title: 'Week 3 review', cohort_id: 'c1', class: 'Section A', professor: 'Purcell Demo', status: 'ended', index: 3, total: 4, question_seconds: 20, join_code: 'K2J9QX', allow_guests: false, created_at: '2026-10-04T11:00:00Z', ended_at: '2026-10-04T11:20:00Z' },
      participants: [{ user_id: 'u1', name: 'Maria Lopez', is_guest: false, joined_at: '2026-10-04T11:02:00Z', answered: 4, correct: 3 }],
      questions: [{ position: 1, question_id: 'q1', stem: 'Which article establishes the judiciary?', answered: 38, correct_rate: 0.5 }],
      timeline,
    },
    isPending: false,
    error: null,
  }),
  useSetFaculty: () => ({ mutate: m.setFaculty, isPending: false, error: null }),
}))

import { PersonPage } from './PersonPage'
import { ClassRecordPage } from './ClassRecordPage'
import { SessionRecordPage } from './SessionRecordPage'

describe('records', () => {
  it('person: three panes, failures highlighted, instructor access action live', async () => {
    render(<PersonPage />)
    expect(screen.getByRole('heading', { name: /Maria Lopez/ })).toBeInTheDocument()
    expect(screen.getByText('maria@mymdc.net')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Section A/ })).toHaveAttribute('href', '#/admin/classes/c1')
    expect(screen.getByText('signin send failed: 429')).toHaveClass('sev-fail')
    expect(screen.getByText(/1.3.2 \(33\)/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /move class/i })).toBeDisabled()
    await userEvent.click(screen.getByRole('button', { name: /grant instructor access/i }))
    await userEvent.click(screen.getByRole('button', { name: /^confirm$/i }))
    expect(m.setFaculty).toHaveBeenCalledWith({ userId: 'u1', verified: true })
  })

  it('class: members link to people, sessions to sessions', () => {
    render(<ClassRecordPage />)
    expect(screen.getByRole('heading', { name: /Section A/ })).toBeInTheDocument()
    expect(screen.getByText('UHHT2B')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Maria Lopez/ })).toHaveAttribute('href', '#/admin/people/u1')
    expect(screen.getByRole('link', { name: /Week 3 review/ })).toHaveAttribute('href', '#/admin/sessions/s1')
  })

  it('session: participants and per-question results', () => {
    render(<SessionRecordPage />)
    expect(screen.getByRole('heading', { name: /Week 3 review/ })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Maria Lopez/ })).toHaveAttribute('href', '#/admin/people/u1')
    expect(screen.getByText(/50%/)).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/admin/records.test.tsx`
Expected: FAIL.

- [ ] **Step 3: Implement**

`web/src/admin/ThreePane.tsx`:

```tsx
import type { ReactNode } from 'react'

/** Linked records left, timeline center, facts and actions right. */
export function ThreePane({
  header,
  left,
  center,
  right,
}: {
  header: ReactNode
  left: ReactNode
  center: ReactNode
  right: ReactNode
}) {
  return (
    <div className="flex flex-col gap-2">
      <div className="admin-panel flex flex-wrap items-baseline gap-3 px-3 py-2">{header}</div>
      <div className="grid gap-2 lg:grid-cols-[220px_1fr_260px]">
        <aside className="admin-panel p-2" aria-label="Linked records">{left}</aside>
        <section className="admin-panel p-2" aria-label="Timeline">{center}</section>
        <aside className="admin-panel p-2" aria-label="Properties and actions">{right}</aside>
      </div>
    </div>
  )
}
```

`web/src/admin/Timeline.tsx`:

```tsx
import type { TimelineEntry } from './adminApi'

const stamp = (iso: string) => {
  const d = new Date(iso)
  return `${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')} ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
}

export function Timeline({ entries }: { entries: TimelineEntry[] }) {
  if (entries.length === 0) return <p className="text-[var(--a-muted)]">Nothing recorded yet.</p>
  return (
    <ol>
      <li className="admin-label mb-1">Timeline · newest first</li>
      {entries.map((e, i) => (
        <li
          key={`${e.at}-${i}`}
          className={e.severity === 'fail' ? '-mx-2 bg-[#2a1214] px-2' : undefined}
        >
          <span className="text-[var(--a-muted)]">{stamp(e.at)}</span>{' '}
          <span className={`sev-${e.severity}`}>{e.kind.toUpperCase()}</span>{' '}
          <span className={e.severity === 'fail' ? 'sev-fail' : undefined}>{e.title}</span>
          {typeof e.detail === 'string' && e.detail ? (
            <span className="text-[var(--a-muted)]"> · {e.detail}</span>
          ) : null}
        </li>
      ))}
    </ol>
  )
}
```

Note for the person test: `screen.getByText('signin send failed: 429')` must resolve to the inner span carrying `sev-fail`; the markup above does that.

`web/src/admin/PersonPage.tsx`:

```tsx
import { useState } from 'react'
import { Link, useParams } from '@tanstack/react-router'
import { useAdminPerson, useSetFaculty } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

const day = (iso: string | null) => (iso ? iso.slice(0, 10) : 'never')

export function PersonPage() {
  const { userId } = useParams({ strict: false }) as { userId: string }
  const person = useAdminPerson(userId)
  const setFaculty = useSetFaculty()
  const [confirming, setConfirming] = useState(false)
  if (person.isPending) return <p>{A.loading}</p>
  if (person.error || !person.data) return <p className="sev-fail">{person.error?.message}</p>
  const p = person.data
  const id = p.identity
  const name = p.memberships.find(m => m.roster_name)?.roster_name ?? id.handle
  const grant = !id.is_faculty

  return (
    <ThreePane
      header={
        <>
          <span className="admin-label">Person</span>
          <h1 className="admin-strong text-sm font-bold">{name}</h1>
          <span>{id.email}</span>
          <span className="text-[var(--a-muted)]">{id.handle}</span>
          <span className="flex-1" />
          {id.is_admin ? <span className="sev-info">ADMIN</span> : null}
          {id.is_faculty ? <span className="sev-ok">INSTRUCTOR</span> : null}
          {p.memberships.some(m => m.role === 'student') ? <span className="sev-ok">STUDENT</span> : null}
        </>
      }
      left={
        <>
          <div className="admin-label">Classes</div>
          {p.memberships.map(m => (
            <div key={m.cohort_id}>
              <Link to="/admin/classes/$cohortId" params={{ cohortId: m.cohort_id }}>▸ {m.name}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{m.role}{m.roster_name ? ` · ${m.roster_name}` : ''}</div>
            </div>
          ))}
          <div className="admin-label mt-2">Live sessions</div>
          {p.sessions.map(s => (
            <div key={s.session_id}>
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }}>▸ {s.title}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{s.correct}/{s.answered} correct</div>
            </div>
          ))}
          <div className="admin-label mt-2">Devices</div>
          {p.devices.map((d, i) => (
            <div key={i} className="text-[var(--a-muted)]">▸ {(d.user_agent ?? 'unknown').slice(0, 40)}</div>
          ))}
          <div className="text-[var(--a-muted)]">push devices: {p.push_devices}</div>
        </>
      }
      center={<Timeline entries={p.timeline} />}
      right={
        <>
          <div className="admin-label">Properties</div>
          <div>created {day(id.created_at)}</div>
          <div>last sign-in {day(id.last_sign_in_at)}</div>
          <div>school {id.school ?? 'none'}</div>
          <div>iOS app {p.app_versions.ios ?? 'not seen'}</div>
          <div>web {p.app_versions.web ?? 'not seen'}</div>
          <div>practice 30d {p.practice.correct_30d}/{p.practice.answers_30d}</div>
          <div className="admin-label mt-3">Actions</div>
          {confirming ? (
            <div className="mt-1 border border-[var(--a-warn)] p-2">
              <p>{grant ? 'Grant' : 'Revoke'} instructor access for {name}?</p>
              <button type="button" className="mr-2 border border-[var(--a-line)] px-2" onClick={() => {
                setFaculty.mutate({ userId: id.user_id, verified: grant })
                setConfirming(false)
              }}>Confirm</button>
              <button type="button" className="border border-[var(--a-line)] px-2" onClick={() => setConfirming(false)}>Cancel</button>
            </div>
          ) : (
            <button type="button" className="mt-1 block w-full border border-[var(--a-line)] px-2 py-1 text-left" onClick={() => setConfirming(true)}>
              {grant ? 'Grant instructor access' : 'Revoke instructor access'}
            </button>
          )}
          {setFaculty.error ? <p className="sev-fail">{setFaculty.error.message}</p> : null}
          {['Move class', 'Sign out everywhere', 'Rename', 'Delete account'].map(label => (
            <button key={label} type="button" disabled title={A.comingIn2b}
              className="mt-1 block w-full cursor-not-allowed border border-[var(--a-line)] px-2 py-1 text-left text-[var(--a-muted)]">
              {label}
            </button>
          ))}
        </>
      }
    />
  )
}
```

`web/src/admin/ClassRecordPage.tsx`:

```tsx
import { Link, useParams } from '@tanstack/react-router'
import { useAdminClass } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

export function ClassRecordPage() {
  const { cohortId } = useParams({ strict: false }) as { cohortId: string }
  const rec = useAdminClass(cohortId)
  if (rec.isPending) return <p>{A.loading}</p>
  if (rec.error || !rec.data) return <p className="sev-fail">{rec.error?.message}</p>
  const c = rec.data
  return (
    <ThreePane
      header={
        <>
          <span className="admin-label">Class</span>
          <h1 className="admin-strong text-sm font-bold">{c.facts.name}</h1>
          <span className="text-[var(--a-muted)]">{c.facts.term ?? ''}</span>
          <span className="flex-1" />
          <span>owner {c.facts.owner ?? 'unknown'}</span>
        </>
      }
      left={
        <>
          <div className="admin-label">Members ({c.members.length})</div>
          {c.members.map(m => (
            <div key={m.user_id}>
              <Link to="/admin/people/$userId" params={{ userId: m.user_id }}>
                ▸ {m.roster_name ?? m.handle ?? 'unknown'}
              </Link>
              <div className="pl-3 text-[var(--a-muted)]">{m.role} · {m.email ?? ''}</div>
            </div>
          ))}
          <div className="admin-label mt-2">Sessions</div>
          {c.sessions.map(s => (
            <div key={s.session_id}>
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }}>▸ {s.title}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{s.status} · {s.participants} joined</div>
            </div>
          ))}
        </>
      }
      center={<Timeline entries={c.timeline} />}
      right={
        <>
          <div className="admin-label">Properties</div>
          <div>join code <span className="admin-strong">{c.facts.join_code}</span></div>
          <div>reporting {c.facts.reporting_resolution ?? 'default'}</div>
          <div>created {c.facts.created_at.slice(0, 10)}</div>
          <div className="admin-label mt-3">Funnel</div>
          <div>members {c.funnel.members}</div>
          <div>students {c.funnel.students}</div>
          <div>answered live {c.funnel.answered_live}</div>
          <div>practiced 7d {c.funnel.practiced_7d}</div>
        </>
      }
    />
  )
}
```

`web/src/admin/SessionRecordPage.tsx`:

```tsx
import { Link, useParams } from '@tanstack/react-router'
import { useAdminSession } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

export function SessionRecordPage() {
  const { sessionId } = useParams({ strict: false }) as { sessionId: string }
  const rec = useAdminSession(sessionId)
  if (rec.isPending) return <p>{A.loading}</p>
  if (rec.error || !rec.data) return <p className="sev-fail">{rec.error?.message}</p>
  const s = rec.data
  return (
    <ThreePane
      header={
        <>
          <span className="admin-label">Session</span>
          <h1 className="admin-strong text-sm font-bold">{s.facts.title}</h1>
          <Link to="/admin/classes/$cohortId" params={{ cohortId: s.facts.cohort_id }}>{s.facts.class}</Link>
          <span className="flex-1" />
          <span className={s.facts.status === 'ended' ? 'text-[var(--a-muted)]' : 'sev-ok'}>
            {s.facts.status.toUpperCase()} · Q{s.facts.index + 1}/{s.facts.total}
          </span>
        </>
      }
      left={
        <>
          <div className="admin-label">Participants ({s.participants.length})</div>
          {s.participants.map(p => (
            <div key={p.user_id}>
              {p.is_guest ? (
                <span>▸ {p.name} (guest)</span>
              ) : (
                <Link to="/admin/people/$userId" params={{ userId: p.user_id }}>▸ {p.name}</Link>
              )}
              <div className="pl-3 text-[var(--a-muted)]">{p.correct}/{p.answered} correct</div>
            </div>
          ))}
        </>
      }
      center={<Timeline entries={s.timeline} />}
      right={
        <>
          <div className="admin-label">Properties</div>
          <div>professor {s.facts.professor ?? 'unknown'}</div>
          <div>code {s.facts.join_code}</div>
          <div>{s.facts.question_seconds}s per question</div>
          <div>guests {s.facts.allow_guests ? 'allowed' : 'off'}</div>
          <div className="admin-label mt-3">Questions</div>
          {s.questions.map(q => (
            <div key={q.question_id} className="mb-1">
              <div>{q.position}. {q.stem}</div>
              <div className="text-[var(--a-muted)]">
                {q.answered} answered · {q.correct_rate == null ? 'n/a' : `${Math.round(q.correct_rate * 100)}%`} correct
              </div>
            </div>
          ))}
        </>
      }
    />
  )
}
```

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run src/admin && npm run typecheck && npm run lint`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web/src/admin
git commit -m "Admin console: three-pane person, class, and session records"
```

---

### Task 9: Invites and audit pages; accessibility check

**Files:**
- Replace: `web/src/admin/InvitesPage.tsx`, `web/src/admin/AuditPage.tsx`
- Create: `web/src/admin/invitesAudit.test.tsx`

**Interfaces:**
- Consumes: `useAdminInvites`, `useMintInvite`, `useRevokeInvite`, `useAdminAudit`, `inviteLink` from `../lib/api`.
- Produces: `InvitesPage()`, `AuditPage()`.

- [ ] **Step 1: Write the failing test**

Create `web/src/admin/invitesAudit.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'

const m = vi.hoisted(() => ({
  mint: vi.fn((_a: unknown, o?: { onSuccess?: (c: string) => void }) => o?.onSuccess?.('D7QMJA')),
  revoke: vi.fn(),
}))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, params, children }: { to: string; params?: Record<string, string>; children: React.ReactNode }) => (
    <a href={`#${Object.entries(params ?? {}).reduce((p, [k, v]) => p.replace(`$${k}`, v), to)}`}>{children}</a>
  ),
}))
vi.mock('../lib/api', () => ({ inviteLink: (c: string) => `https://politiface.app/app/#/welcome?invite=${c}` }))
vi.mock('./adminApi', () => ({
  useAdminInvites: () => ({
    data: [
      { code: 'AAAAAA', note: 'For Prof. X', minted_by_handle: 'DawoodShah', recipient_email: 'x@mdc.edu', uses: 0, max_uses: 1, created_at: '2026-10-01T00:00:00Z', expires_at: '2026-10-15T00:00:00Z', revoked_at: null, status: 'active' },
      { code: 'BBBBBB', note: null, minted_by_handle: 'DawoodShah', recipient_email: null, uses: 1, max_uses: 1, created_at: '2026-09-20T00:00:00Z', expires_at: '2026-10-04T00:00:00Z', revoked_at: null, status: 'used' },
    ],
    isPending: false,
    error: null,
  }),
  useMintInvite: () => ({ mutate: m.mint, isPending: false, error: null }),
  useRevokeInvite: () => ({ mutate: m.revoke, isPending: false, error: null }),
  useAdminAudit: () => ({
    data: [{ id: 1, created_at: '2026-10-04T12:00:00Z', actor_handle: 'bright_quill_1321', action: 'faculty_granted', target_user: 'u1', target_label: 'Purcell Demo', target_cohort: null, target_session: null, details: {} }],
    isPending: false,
    error: null,
  }),
}))

import { InvitesPage } from './InvitesPage'
import { AuditPage } from './AuditPage'

describe('InvitesPage', () => {
  it('lists invites with status, mints a link, revokes only active ones', async () => {
    render(<InvitesPage />)
    expect(screen.getByText('AAAAAA')).toBeInTheDocument()
    expect(screen.getByText('active')).toBeInTheDocument()
    expect(screen.getByText('used')).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: /revoke/i })).toHaveLength(1)
    await userEvent.click(screen.getByRole('button', { name: /revoke/i }))
    expect(m.revoke).toHaveBeenCalledWith('AAAAAA')
    await userEvent.type(screen.getByLabelText(/their email/i), 'new@mdc.edu')
    await userEvent.click(screen.getByRole('button', { name: /create invite link/i }))
    expect(m.mint.mock.calls[0][0]).toEqual({ recipientEmail: 'new@mdc.edu', note: '' })
    expect(screen.getByDisplayValue(/invite=D7QMJA/)).toBeInTheDocument()
  })

  it('has no axe violations', async () => {
    const { container } = render(<div className="admin-root"><InvitesPage /></div>)
    const results = await axe(container)
    expect(results.violations).toEqual([])
  })
})

describe('AuditPage', () => {
  it('lists admin actions with actor and target', () => {
    render(<AuditPage />)
    expect(screen.getByText('bright_quill_1321')).toBeInTheDocument()
    expect(screen.getByText('faculty granted')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Purcell Demo' })).toHaveAttribute('href', '#/admin/people/u1')
  })
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd web && npx vitest run src/admin/invitesAudit.test.tsx`
Expected: FAIL.

- [ ] **Step 3: Implement**

`web/src/admin/InvitesPage.tsx`:

```tsx
import { useState, type FormEvent } from 'react'
import { inviteLink } from '../lib/api'
import { useAdminInvites, useMintInvite, useRevokeInvite } from './adminApi'
import { A } from './strings'

const tone: Record<string, string> = {
  active: 'sev-ok',
  used: 'text-[var(--a-muted)]',
  expired: 'sev-warn',
  revoked: 'sev-fail',
}

export function InvitesPage() {
  const invites = useAdminInvites()
  const mint = useMintInvite()
  const revoke = useRevokeInvite()
  const [email, setEmail] = useState('')
  const [note, setNote] = useState('')
  const [link, setLink] = useState<string | null>(null)

  const submit = (e: FormEvent) => {
    e.preventDefault()
    mint.mutate(
      { recipientEmail: email.trim(), note: note.trim() },
      { onSuccess: code => setLink(inviteLink(code)) },
    )
  }

  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.invites}</h1>
      <form onSubmit={submit} className="admin-panel flex flex-wrap items-end gap-2 p-2">
        <label className="flex flex-col">
          <span className="admin-label">Their email (optional)</span>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)}
            className="border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]" />
        </label>
        <label className="flex flex-col">
          <span className="admin-label">Note (optional)</span>
          <input value={note} onChange={e => setNote(e.target.value)} maxLength={120}
            className="border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]" />
        </label>
        <button type="submit" disabled={mint.isPending} className="border border-[var(--a-info)] px-3 py-1 text-[var(--a-info)]">
          Create invite link
        </button>
        {link ? (
          <input readOnly aria-label="Invite link" value={link} onFocus={e => e.currentTarget.select()}
            className="min-w-[320px] flex-1 border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]" />
        ) : null}
        {mint.error ? <p className="sev-fail">{mint.error.message}</p> : null}
      </form>
      <table className="admin-panel w-full">
        <thead>
          <tr className="admin-label text-left">
            <th scope="col" className="p-1">Code</th><th scope="col">Status</th><th scope="col">For</th>
            <th scope="col">By</th><th scope="col">Expires</th><th scope="col"><span className="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody>
          {(invites.data ?? []).map(i => (
            <tr key={i.code} className="border-t border-[var(--a-line)]">
              <td className="admin-strong p-1">{i.code}</td>
              <td className={tone[i.status]}>{i.status}</td>
              <td>{i.recipient_email ?? i.note ?? ''}</td>
              <td>{i.minted_by_handle ?? ''}</td>
              <td>{i.expires_at.slice(0, 10)}</td>
              <td>
                {i.status === 'active' ? (
                  <button type="button" onClick={() => revoke.mutate(i.code)}
                    className="border border-[var(--a-line)] px-2 text-[var(--a-fail)]">
                    Revoke
                  </button>
                ) : null}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

`web/src/admin/AuditPage.tsx`:

```tsx
import { Link } from '@tanstack/react-router'
import { useAdminAudit } from './adminApi'
import { A } from './strings'

export function AuditPage() {
  const audit = useAdminAudit()
  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.audit}</h1>
      <table className="admin-panel w-full">
        <thead>
          <tr className="admin-label text-left">
            <th scope="col" className="p-1">When</th><th scope="col">Who</th>
            <th scope="col">Action</th><th scope="col">Target</th>
          </tr>
        </thead>
        <tbody>
          {(audit.data ?? []).map(a => (
            <tr key={a.id} className="border-t border-[var(--a-line)]">
              <td className="p-1 text-[var(--a-muted)]">{a.created_at.replace('T', ' ').slice(0, 16)}</td>
              <td>{a.actor_handle ?? 'unknown'}</td>
              <td>{a.action.replace(/_/g, ' ')}</td>
              <td>
                {a.target_user ? (
                  <Link to="/admin/people/$userId" params={{ userId: a.target_user }}>{a.target_label ?? 'person'}</Link>
                ) : a.target_cohort ? (
                  <Link to="/admin/classes/$cohortId" params={{ cohortId: a.target_cohort }}>{a.target_label ?? 'class'}</Link>
                ) : a.target_session ? (
                  <Link to="/admin/sessions/$sessionId" params={{ sessionId: a.target_session }}>{a.target_label ?? 'session'}</Link>
                ) : (
                  <span className="text-[var(--a-muted)]">console</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 4: Run tests**

Run: `cd web && npx vitest run && npm run typecheck && npm run lint && npm run build`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add web/src/admin
git commit -m "Admin console: invites and audit pages"
```

---

### Task 10: iOS problem logging

**Files:**
- Create: `app/lib/core/ops/ops_log.dart`, `app/test/core/ops/ops_log_test.dart`
- Modify: `app/lib/core/sync/sign_in_sheet.dart`, `app/lib/features/live/data/live_session_api.dart`, `app/lib/main.dart`

**Interfaces:**
- Produces: `OpsLog.report(String kind, {String? code, Map<String, Object?>? detail, String? email})` returning `Future<void>`, never throws; `OpsLog.sinkOverride` (test seam): `Future<void> Function(Map<String, dynamic> params)?`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/ops/ops_log_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/ops/ops_log.dart';
import 'package:politiface/core/sync/auth_service.dart';
import 'package:politiface/core/sync/sign_in_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RateLimitedAuth extends AuthService {
  _RateLimitedAuth() : super(SupabaseClient('http://localhost', 'test-key'));

  @override
  Future<void> requestOtp(String email) async =>
      throw const AuthException('rate limit', statusCode: '429');
}

void main() {
  late List<Map<String, dynamic>> sent;
  setUp(() {
    sent = [];
    OpsLog.sinkOverride = (p) async => sent.add(p);
  });
  tearDown(() => OpsLog.sinkOverride = null);

  test('report sends kind, client ios, and details', () async {
    await OpsLog.report('join_refused', code: 'invalid or ended session code');
    expect(sent.single['p_kind'], 'join_refused');
    expect(sent.single['p_client'], 'ios');
    expect(sent.single['p_code'], 'invalid or ended session code');
  });

  test('report never throws when sending fails', () async {
    OpsLog.sinkOverride = (_) async => throw Exception('offline');
    await OpsLog.report('client_error', code: 'x');
  });

  testWidgets('a failed code send reports signin_send_failed with the email',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SignInSheet(auth: _RateLimitedAuth()))),
    );
    await tester.enterText(find.byType(TextField), 'Maria@MyMDC.net');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    expect(sent.single['p_kind'], 'signin_send_failed');
    expect(sent.single['p_code'], '429');
    expect(sent.single['p_email'], 'Maria@MyMDC.net');
  });
}
```

If `AuthService`'s constructor signature differs from `AuthService(SupabaseClient)`, read `app/lib/core/sync/auth_service.dart` and adapt `_RateLimitedAuth` to it.

- [ ] **Step 2: Run to verify it fails**

Run: `cd app && flutter test test/core/ops/ops_log_test.dart`
Expected: FAIL (cannot find `ops_log.dart`).

- [ ] **Step 3: Implement**

`app/lib/core/ops/ops_log.dart`:

```dart
// Problem log (admin console 2a): fire-and-forget reports of what went
// wrong for a user, shown on their timeline in the founders' console.
// Never blocks or breaks a flow; failures to log are swallowed.

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/supabase_config.dart';

class OpsLog {
  OpsLog._();

  /// Test seam: when set, receives the RPC params instead of Supabase.
  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> params)? sinkOverride;

  static String? _version;

  static Future<String?> _appVersion() async {
    if (_version != null) return _version;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      _version = null;
    }
    return _version;
  }

  static Future<void> report(
    String kind, {
    String? code,
    Map<String, Object?>? detail,
    String? email,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_kind': kind,
        'p_client': 'ios',
        'p_code': code == null || code.length <= 80 ? code : code.substring(0, 80),
        'p_detail': detail,
        'p_app_version': sinkOverride != null ? null : await _appVersion(),
        'p_email': email,
      };
      final sink = sinkOverride;
      if (sink != null) {
        await sink(params);
        return;
      }
      if (!SupabaseConfig.isConfigured) return;
      await Supabase.instance.client.rpc<void>('log_ops_event', params: params);
    } catch (_) {
      // never let logging break the caller
    }
  }
}
```

`app/lib/core/sync/sign_in_sheet.dart`: import `../ops/ops_log.dart`; in `_run`, capture `final verifying = _codeSent;` before `await action();`, and in the `catch (e)` block, before `setState`, add:

```dart
      unawaited(OpsLog.report(
        verifying ? 'signin_verify_failed' : 'signin_send_failed',
        code: e is AuthException ? (e.statusCode ?? e.code ?? 'auth') : 'thrown',
        email: _email.text.trim(),
      ));
```

(import `dart:async` for `unawaited` and `package:supabase_flutter/supabase_flutter.dart` show `AuthException` if not already imported; if `AuthException` has no `code` getter in this supabase version, use `e.statusCode ?? 'auth'`.)

`app/lib/features/live/data/live_session_api.dart`: wrap the body of the Supabase `joinByCode` in `try { ... } on PostgrestException catch (e) { unawaited(OpsLog.report('join_refused', code: e.message, detail: {'session_code': code.trim()})); rethrow; }`.

`app/lib/main.dart`: in `_bootstrap` before `runApp`, chain error reporting:

```dart
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    unawaited(OpsLog.report(
      'client_error',
      code: 'flutter_error',
      detail: {
        'message': message.length <= 300 ? message : message.substring(0, 300),
      },
    ));
    previousOnError?.call(details);
  };
```

and in the auth listener, next to each `pushService.onSignedIn()` call guarded by a real session (`signedIn`, and `initialSession` with `state.session != null`), add `unawaited(OpsLog.report('app_seen'));`.

- [ ] **Step 4: Run tests and analyzer**

Run: `cd app && flutter test && flutter analyze`
Expected: all tests pass; analyzer shows only the 4 pre-existing infos in `pulse` files.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/ops app/test/core/ops app/lib/core/sync/sign_in_sheet.dart app/lib/features/live/data/live_session_api.dart app/lib/main.dart
git commit -m "App: report sign-in failures, refused joins, errors, and app version"
```

---

### Task 11: Replace the legacy /faculty admin tab

**Files:**
- Modify: `docs/faculty/index.html`

- [ ] **Step 1: Find every admin reference**

Run: `grep -n "admin\|Admin\|mint-invite\|invite-note\|runAdminSearch" docs/faculty/index.html`
Record the line ranges of: the Admin view markup (the container shown when admin mode is on, containing "Command center", "All classes", "All live sessions", "Find user", "Instructor invites"), and the script blocks `setAdminMode`, `loadAdmin`, `runAdminSearch`, `renderAdminSearchResults`, the `btn-mint-invite` handler, and any `$("admin-...")` usage.

- [ ] **Step 2: Replace**

- Keep the `admin-toggle-row` and `nav-admin-btn` button (still shown only to admins via the existing `am_admin` check), but change its click handler to navigate: `$("nav-admin-btn").onclick = () => { window.location.href = "../app/#/admin"; };` and its label to `Admin console ↗`.
- Delete the Admin view markup and every admin-only script function listed in Step 1, and every call site that referenced them (for example `setAdminMode(false)` calls in sign-out paths and `loadAdmin()`), keeping the `isAdmin` detection that decides whether the button shows.
- Ensure no remaining `$("admin-`, `btn-mint-invite`, `invite-note`, `admin_search_users`, `admin_set_faculty`, `admin_list_invites`, `admin_overview`, `admin_list_cohorts`, `admin_list_live_sessions` references remain.

- [ ] **Step 3: Verify the portal still loads and works**

Run: `grep -nE '\$\("admin-|btn-mint-invite|invite-note|admin_(search_users|set_faculty|list_invites|overview|list_cohorts|list_live_sessions)' docs/faculty/index.html`
Expected: no output.

Run a syntax check of the inline script: extract the main `<script type="module">` contents into a temp file and run `node --check` on it (it is plain JS):

```bash
python3 - <<'EOF'
import re
s=open('docs/faculty/index.html').read()
blocks=re.findall(r'<script type="module">(.*?)</script>', s, re.S)
open('/tmp/faculty_check.mjs','w').write('\n'.join(blocks))
EOF
node --check /tmp/faculty_check.mjs && echo "syntax ok"
```

Expected: `syntax ok`.

- [ ] **Step 4: Commit**

```bash
git add docs/faculty/index.html
git commit -m "Legacy portal: Admin tab now opens the new admin console"
```

---

### Task 12: Ship

**Files:**
- Modify: `web/src/lib/database.types.ts` (regenerated), `docs/app/**`

- [ ] **Step 1: Full local verification**

Run: `./supabase/tests/run_local.sh 2>&1 | tail -1 && cd web && npx vitest run && npm run typecheck && npm run build && cd ../app && flutter test && flutter analyze`
Expected: all green; analyzer only the 4 pre-existing infos.

- [ ] **Step 2: Founder applies the migration**

Build a one-transaction script and hand it to the founder:

```bash
OUT=$CLAUDE_JOB_DIR/tmp/apply_admin_console.sql
{ echo "begin;"; cat supabase/migrations/20261004000200_admin_console.sql; echo;
  echo "insert into supabase_migrations.schema_migrations (version, name) values ('20261004000200', 'admin_console');";
  echo "commit;"; } > "$OUT"
```

The founder runs `! pbcopy < <that path>` and pastes into the Supabase SQL editor.

- [ ] **Step 3: Verify production (read-only)**

```bash
supabase db query --linked "select string_agg(proname, ',' order by proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and proname like 'admin\_%' escape '\\' or proname = 'log_ops_event'"
supabase db query --linked "select to_regclass('app.admin_audit') is not null audit, to_regclass('app.ops_events') is not null ops"
```

Expected: the new admin functions and `log_ops_event` listed; both tables present.

- [ ] **Step 4: Regenerate types, build, publish**

Follow the established path (memory `web_console_deploy_path.md`): regenerate `database.types.ts` from production keeping the 4-line header, typecheck, `web/scripts/sync-to-docs.sh`, commit, push `v2-planning`, merge `origin/main` with v2-planning's side after the history check, open the PR, wait for CI, squash-merge, confirm Pages served the new bundle (grep it for `POLITIFACE // CONSOLE`).

- [ ] **Step 5: Live check**

Sign in at `politiface.app/app` as an admin, click Console, confirm Home loads, open a person, confirm the Audit page shows `console open` and `view person`.
