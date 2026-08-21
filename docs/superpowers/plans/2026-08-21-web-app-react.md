# Web App (React) Implementation Plan — Plan B

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The faculty web app and student live-join page as a React SPA in `web/`, rendering the backend spine's RPCs, deployed as static files under `docs/app/` on the existing GitHub Pages site.

**Architecture:** Vite + React + TypeScript SPA. Hash-based routing (`#/...`) so the app works unchanged at `rkapdi.github.io/politiFace/app/` today and `politiface.app/app/` later, with no server rewrites. Supabase (Auth + RPC) is the only backend; all authorization stays server-side. TanStack Query owns data fetching; every metric comes from a spine RPC, nothing is computed client-side. Build output is synced into `docs/app/` and committed (the repo deploys Pages from the branch; no repo-settings change needed).

**Tech Stack:** Vite 6, React 19, TypeScript, @tanstack/react-router (hash history) + @tanstack/react-query, Tailwind CSS v4 (via `@tailwindcss/vite`), Radix primitives (`@radix-ui/react-tabs`, `@radix-ui/react-dialog`) with hand-styled components (the shadcn approach without the CLI), Recharts, `qrcode`, `@supabase/supabase-js`, Vitest + Testing Library + jsdom + vitest-axe.

**Spec:** `docs/superpowers/specs/2026-08-21-web-app-foundation-design.md` (Phase 2)

## Global Constraints

- No em-dashes in any user-facing copy (house rule; commas, periods, colons, parentheses instead).
- Never collect political affiliation or voting history. The only student-typed field in this app is the guest display name.
- The SPA treats itself as untrusted: route guards are UX only; every privileged call is a spine RPC that re-checks the caller.
- Positioning copy: "supplemental practice students choose", never "official prep".
- Supabase project: url `https://sbjpiajjlufrhigmovnk.supabase.co`, publishable anon key `sb_publishable_BIJdeOXfjzXlJhsc8bX_Fw_YNX902qU` (public by design, RLS is the guard; same values as `docs/faculty/config.js`).
- All work on branch `v2-planning`. Run tests from `web/` with `npm test -- --run`; typecheck with `npm run typecheck`.
- Accessibility: every interactive element keyboard-reachable, labelled inputs, `role="alert"` on error/status messages, table headers with `scope="col"`, WCAG 2.1 AA contrast.
- WHEN A TASK FINISHES, the app must still build (`npm run build`) even if later routes are stubs.

## File Structure

```
web/
  package.json  vite.config.ts  tsconfig.json  index.html
  src/
    main.tsx                 entry: providers + router
    styles.css               tailwind + design tokens
    lib/
      config.ts              supabase url + anon key
      database.types.ts      GENERATED from hosted schema (Supabase MCP / CLI)
      supabase.ts            typed client singleton
      api.ts                 typed RPC wrappers + TanStack Query hooks
      csv.ts                 toCsv + downloadCsv
      live.ts                countdown math + phase helpers (pure)
    auth/
      SessionProvider.tsx    session context (OTP sign-in, sign-out)
      SignIn.tsx             email OTP screen
      RequireAuth.tsx        gate for faculty routes
    routes/
      router.tsx             route tree (hash history)
      Layout.tsx             app shell nav
      ClassesPage.tsx        my_faculty_overview cards
      ClassPage.tsx          tabs: Overview / Students / Live / Settings
      StudentPage.tsx        student_drilldown
      LiveRunnerPage.tsx     faculty phase-machine console
      JoinPage.tsx           guest join + answer loop (outside RequireAuth)
    components/
      ui.tsx                 Button, Card, Stat, Badge, Alert, Spinner, Tabs
      DomainBars.tsx         per-domain readiness bars
      TrendChart.tsx         engagement area chart (Recharts)
      TopMisses.tsx          most-missed questions table
      AtRiskTable.tsx        ranked at-risk list
      ProgressTable.tsx      full roster progress table
      PolicyBanner.tsx       what the current reporting policy exposes
      PolicyEditor.tsx       set_reporting_policy form
      StaffEditor.tsx        add TA / co-faculty, remove TA
      QuestionPicker.tsx     compose a live session
      Scoreboard.tsx         live standings
      Countdown.tsx          server-anchored countdown ring
  scripts/
    sync-to-docs.sh          dist -> ../docs/app (committed)
.github/workflows/web-ci.yml
docs/app/                    committed build output
```

---

### Task 1: Scaffold, typed Supabase client, test harness

**Files:**
- Create: `web/package.json`, `web/vite.config.ts`, `web/tsconfig.json`, `web/index.html`, `web/src/main.tsx`, `web/src/styles.css`, `web/src/lib/config.ts`, `web/src/lib/database.types.ts`, `web/src/lib/supabase.ts`, `web/src/lib/csv.ts`, `web/src/lib/csv.test.ts`

**Interfaces:**
- Produces: `supabase` (typed `SupabaseClient<Database>` singleton), `toCsv(rows: Record<string, unknown>[]): string`, `downloadCsv(filename: string, rows: Record<string, unknown>[]): void`, npm scripts `dev`, `build`, `test`, `typecheck`.

- [ ] **Step 1: Scaffold.** From repo root: `npm create vite@latest web -- --template react-ts`, then in `web/`: `npm i @supabase/supabase-js @tanstack/react-router @tanstack/react-query recharts qrcode @radix-ui/react-tabs @radix-ui/react-dialog` and `npm i -D tailwindcss @tailwindcss/vite vitest @testing-library/react @testing-library/user-event @testing-library/jest-dom jsdom vitest-axe @types/qrcode`. Set `vite.config.ts`:

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test-setup.ts'],
  },
})
```

Add `web/src/test-setup.ts` importing `@testing-library/jest-dom/vitest`. Add scripts to `package.json`: `"test": "vitest"`, `"typecheck": "tsc --noEmit"`. Add `/// <reference types="vitest/config" />` at the top of `vite.config.ts` so the `test` key typechecks.

- [ ] **Step 2: Generate database types.** Use the Supabase MCP tool `generate_typescript_types` (project `sbjpiajjlufrhigmovnk`) and write the output verbatim to `web/src/lib/database.types.ts`. (CLI equivalent for humans: `supabase gen types typescript --project-id sbjpiajjlufrhigmovnk`.) This file is regenerated, never hand-edited.

- [ ] **Step 3: Config + client.**

```ts
// web/src/lib/config.ts
// The publishable/anon key is a PUBLIC client credential by design
// (row-level security is the guard); same values as docs/faculty/config.js.
export const SUPABASE_URL = 'https://sbjpiajjlufrhigmovnk.supabase.co'
export const SUPABASE_ANON_KEY = 'sb_publishable_BIJdeOXfjzXlJhsc8bX_Fw_YNX902qU'
```

```ts
// web/src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config'

export const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY)
```

- [ ] **Step 4: Write the failing csv test** (`web/src/lib/csv.test.ts`):

```ts
import { describe, expect, it } from 'vitest'
import { toCsv } from './csv'

describe('toCsv', () => {
  it('renders headers from keys and escapes quotes, commas, newlines', () => {
    const csv = toCsv([
      { name: 'Alex "A" R', note: 'line1\nline2', score: 3 },
      { name: 'plain', note: 'a,b', score: null },
    ])
    expect(csv.split('\r\n')[0]).toBe('name,note,score')
    expect(csv).toContain('"Alex ""A"" R"')
    expect(csv).toContain('"line1\nline2"')
    expect(csv).toContain('"a,b"')
    expect(csv.endsWith('plain,"a,b",')).toBe(true)
  })
})
```

- [ ] **Step 5: Run to verify it fails.** `npm test -- --run` in `web/`. Expected: FAIL (csv.ts missing).

- [ ] **Step 6: Implement csv.ts**

```ts
// web/src/lib/csv.ts
export function toCsv(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return ''
  const headers = Object.keys(rows[0])
  const cell = (v: unknown): string => {
    if (v === null || v === undefined) return ''
    const s = String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  return [headers.join(','), ...rows.map(r => headers.map(h => cell(r[h])).join(','))]
    .join('\r\n')
}

export function downloadCsv(filename: string, rows: Record<string, unknown>[]): void {
  const blob = new Blob([toCsv(rows)], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = filename
  a.click()
  URL.revokeObjectURL(a.href)
}
```

- [ ] **Step 7: Verify green + builds.** `npm test -- --run && npm run typecheck && npm run build`. Expected: all pass.

- [ ] **Step 8: Commit.** `git add web && git commit -m "Web app: Vite + React scaffold with typed Supabase client"`

---

### Task 2: Auth shell and router skeleton

**Files:**
- Create: `web/src/auth/SessionProvider.tsx`, `web/src/auth/SignIn.tsx`, `web/src/auth/RequireAuth.tsx`, `web/src/routes/router.tsx`, `web/src/routes/Layout.tsx`, stub pages (`ClassesPage.tsx`, `ClassPage.tsx`, `StudentPage.tsx`, `LiveRunnerPage.tsx`, `JoinPage.tsx` each rendering their name), `web/src/components/ui.tsx`
- Modify: `web/src/main.tsx`
- Test: `web/src/auth/auth.test.tsx`

**Interfaces:**
- Produces: `useSession(): { session: Session | null, loading: boolean, signOut(): Promise<void> }`; `<SignIn/>` performs `supabase.auth.signInWithOtp({ email })` then `supabase.auth.verifyOtp({ email, token, type: 'email' })`; routes `#/` (classes), `#/class/$cohortId`, `#/class/$cohortId/student/$studentRef`, `#/class/$cohortId/live/$sessionId`, `#/join` (public); ui.tsx exports `Button, Card, Stat, Badge, Alert, Spinner, Tabs` (Tabs re-exported from Radix with styles).

- [ ] **Step 1: Write the failing test** (`web/src/auth/auth.test.tsx`): mock `../lib/supabase` with `vi.mock`; `getSession` resolves null session and `onAuthStateChange` returns an unsubscribable; assert that rendering `<RequireAuth><p>secret</p></RequireAuth>` inside `SessionProvider` shows the sign-in email field and not `secret`; assert `<SignIn/>` submit calls `signInWithOtp` with the typed email and then swaps to the 6-digit code field.

```tsx
import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const signInWithOtp = vi.fn(async () => ({ error: null }))
const verifyOtp = vi.fn(async () => ({ data: {}, error: null }))
vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: async () => ({ data: { session: null } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      signInWithOtp,
      verifyOtp,
    },
  },
}))

import { SessionProvider } from './SessionProvider'
import { RequireAuth } from './RequireAuth'

describe('auth shell', () => {
  it('gates content behind sign-in and starts the OTP flow', async () => {
    render(
      <SessionProvider>
        <RequireAuth><p>secret</p></RequireAuth>
      </SessionProvider>,
    )
    expect(screen.queryByText('secret')).toBeNull()
    const email = await screen.findByLabelText(/email/i)
    await userEvent.type(email, 'prof@example.edu')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    expect(signInWithOtp).toHaveBeenCalledWith({ email: 'prof@example.edu' })
    expect(await screen.findByLabelText(/code/i)).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: Run to verify it fails.** `npm test -- --run`. Expected: FAIL (modules missing).

- [ ] **Step 3: Implement.** `SessionProvider` holds `{ session, loading }` from `getSession()` + `onAuthStateChange`. `RequireAuth` renders `<Spinner/>` while loading, `<SignIn/>` when no session, children otherwise. `SignIn` is a two-step form (email -> code) with labelled inputs, error `<Alert role="alert">`, and copy: "Sign in to the Politiface faculty console. We email you a 6-digit code; there is no password." `ui.tsx` implements the primitives with Tailwind classes (focus-visible rings, `aria-busy` on Spinner). Router (`router.tsx`): TanStack Router with `createHashHistory()`; `/join` renders `JoinPage` directly; everything else wraps in `Layout` + `RequireAuth`. `Layout` nav: brand "Politiface", link "Your classes", sign-out button, `<main id="main">` landmark and a skip link.

- [ ] **Step 4: Verify.** `npm test -- --run && npm run typecheck && npm run build`. Expected: green.

- [ ] **Step 5: Commit.** `git commit -m "Web app: OTP auth shell and hash router"`

---

### Task 3: Typed API layer

**Files:**
- Create: `web/src/lib/api.ts`
- Test: `web/src/lib/api.test.ts`

**Interfaces:**
- Consumes: `supabase` (Task 1), generated `Database` types.
- Produces (exact export names later tasks use; every hook wraps TanStack Query and every mutation invalidates its cohort's queries):
  - `rpc<T>(fn, args): Promise<T>` internal helper that throws `new Error(friendlyMessage(error))`.
  - `friendlyMessage(error: { message: string }): string` maps known raise texts ('not faculty of this cohort', 'this class reports aggregate data only', 'invalid or ended session code', 'enter a display name (2 to 40 characters)') to plain sentences and everything else to 'Something went wrong on our side. Try again.'
  - Query hooks: `useMyClasses()` (`my_faculty_overview`), `useCohortRole(cohortId)` (`my_cohort_role`), `useReportingPolicy(cohortId)` (`get_reporting_policy`), `useCohortOverview(cohortId)`, `useDomainStats(cohortId)`, `useTopMisses(cohortId)`, `useEngagementTrend(cohortId, days)`, `useAtRisk(cohortId, threshold)` (`at_risk_students`), `useStudentProgress(cohortId)` (`cohort_student_progress`), `useDrilldown(cohortId, studentRef)` (`student_drilldown`), `useCohortSessions(cohortId)` (`cohort_live_sessions`), `useSessionReport(sessionId)` (`live_session_report`), `useSessionStats(sessionId)` (`live_session_stats`).
  - Mutations: `useSetReportingPolicy()`, `useLogExport()` (`log_report_export`), `useAddTa()`, `useRemoveTa()`, `useAddCoFaculty()`, `useSendAnnouncement()` (`send_class_announcement`), `useCreateLiveSession()`, `useAdvanceLiveSession()`, `useEndLiveSession()`.
  - Guest/live plain functions (no auth context assumptions): `joinLiveSessionGuest(code, displayName)`, `getLiveQuestion(sessionId)`, `submitLiveAnswer(sessionId, questionId, key)`, `liveReveal(sessionId)`, `liveScoreboard(sessionId)`, `signInAnonymously()` (`supabase.auth.signInAnonymously()`).
  - `AtRiskRow`, `ProgressRow`, `Drilldown` type aliases derived from `Database['public']['Functions']`.

- [ ] **Step 1: Write the failing test** (`web/src/lib/api.test.ts`): mock `./supabase` with a `vi.fn()` `rpc` returning `{ data: [{ ok: true }], error: null }`; assert `friendlyMessage({ message: 'this class reports aggregate data only' })` returns the aggregate explainer sentence; assert calling the exported `atRiskStudents('c1', 0.6)` fetcher invokes `supabase.rpc('at_risk_students', { p_cohort: 'c1', p_threshold: 0.6 })`; assert an error response makes the fetcher throw the friendly message not the raw one.

- [ ] **Step 2: Run to verify it fails, then implement.** All fetchers are named plain async functions (`atRiskStudents`, `cohortOverview`, ...) plus thin hooks (`useAtRisk` = `useQuery({ queryKey: ['at-risk', cohortId, threshold], queryFn: ... })`). Mutations use `useMutation` with `onSuccess` invalidating `[cohortId]`-prefixed keys.

- [ ] **Step 3: Verify green + typecheck + build. Commit.** `git commit -m "Web app: typed RPC layer with friendly errors"`

---

### Task 4: Classes page

**Files:**
- Create: real `web/src/routes/ClassesPage.tsx`
- Test: `web/src/routes/ClassesPage.test.tsx`

**Interfaces:**
- Consumes: `useMyClasses()`. Row shape: `{ cohort_id, name, term, students, active_7d, answers_total, accuracy, mocks_completed, live_sessions }` (nullable stats below the 5-student floor).

- [ ] **Step 1: Failing test:** mock `../lib/api`; `useMyClasses` returns two classes, one with null stats. Assert both names render as links to `#/class/<id>`, the null-stats class shows "Stats appear at 5 students" and the other shows its numbers.
- [ ] **Step 2: Implement.** Card grid; each card: class name, term badge, students, active this week, answers, mocks, live session count; empty state: "No classes yet. Create your class in the current faculty portal; this console picks it up automatically." (Class creation stays in the old portal this sprint.)
- [ ] **Step 3: Verify + commit.** `git commit -m "Web app: classes dashboard"`

---

### Task 5: Class overview tab

**Files:**
- Create: real `web/src/routes/ClassPage.tsx` (tab shell + Overview tab), `web/src/components/DomainBars.tsx`, `web/src/components/TrendChart.tsx`, `web/src/components/TopMisses.tsx`, `web/src/components/PolicyBanner.tsx`
- Test: `web/src/routes/ClassPage.test.tsx`

**Interfaces:**
- Consumes: `useCohortOverview`, `useDomainStats` (`{ domain_code, domain_name, students, answers, accuracy }`), `useTopMisses` (`{ question_id, stem, domain_code, students, attempts, miss_rate }`), `useEngagementTrend` (`{ day, active_students, answers }`), `useReportingPolicy` (`{ resolution, identity_display, raw_retention_days, effective }`), `useCohortRole`.
- Produces: `<ClassPage>` with Radix tabs `Overview | Students | Live | Settings`; `PolicyBanner` copy per effective policy (per_student: "This class reports per-student detail to faculty."; pseudonymous: "Students appear under stable pseudonyms."; aggregate_only: "This class reports aggregate data only."). Settings tab hidden for TAs (`my_cohort_role === 'ta'`).

- [ ] **Step 1: Failing test:** mock api; assert the four stat values render, DomainBars shows one labelled bar per domain with percentage text, and the aggregate_only policy string appears when the mocked policy says so.
- [ ] **Step 2: Implement.** Overview tab: Stat row (students, active 7d, answers, mocks), `TrendChart` (Recharts `AreaChart` of answers + active students, 28 days, `<title>` and visually-hidden data table for screen readers), `DomainBars` (accessible: each bar is a `<div role="img" aria-label="Domain 1 Constitutional principles, 62 percent accuracy">`), `TopMisses` table (`scope="col"` headers, stem truncated with full text in `title`). Below-floor states render the explainer, never empty charts. Also a "Summary one-pager" button: fetches the existing `efficacy-report` edge function (`{SUPABASE_URL}/functions/v1/efficacy-report?cohort=<id>` with header `Authorization: Bearer <session.access_token>`), opens the returned HTML in a new window, and logs the export as kind `one_pager` via `useLogExport`.
- [ ] **Step 3: Verify + commit.** `git commit -m "Web app: class overview with domain and engagement analytics"`

---

### Task 6: Students tab (at-risk + roster + exports)

**Files:**
- Create: `web/src/components/AtRiskTable.tsx`, `web/src/components/ProgressTable.tsx`; wire into `ClassPage.tsx` Students tab
- Test: `web/src/components/students.test.tsx`

**Interfaces:**
- Consumes: `useAtRisk(cohortId, 0.6)` rows `{ student_ref, display_name, overall_readiness, weakest_domain_id, weakest_domain_name, weakest_readiness, last_active, answers_14d }`; `useStudentProgress(cohortId)` rows `{ user_id, roster_name, handle, last_active, answers_total, accuracy, mocks_completed, best_mock_score, student_ref }`; `useLogExport`; `downloadCsv`.
- Produces: rows link to `#/class/$cohortId/student/$studentRef`. Export buttons call `useLogExport().mutate({ cohortId, kind })` with kind `csv_at_risk` / `csv_progress` then `downloadCsv`.

- [ ] **Step 1: Failing test:** with mocked api, assert: at-risk rows render ranked with weakest domain and "n days ago" recency; clicking "Export CSV" calls the export logger with `csv_at_risk` and triggers a download (spy on `downloadCsv` via module mock); when `useAtRisk` errors with the aggregate-only friendly message, the tab shows that message and no table.
- [ ] **Step 2: Implement.** At-risk list first ("Who needs you first"), full roster below; readiness rendered as percent + bar; `last_active` as relative days; aggregate_only error state renders the PolicyBanner explainer instead of tables.
- [ ] **Step 3: Verify + commit.** `git commit -m "Web app: at-risk list, roster progress, logged CSV exports"`

---

### Task 7: Student drill-down page

**Files:**
- Create: real `web/src/routes/StudentPage.tsx`
- Test: `web/src/routes/StudentPage.test.tsx`

**Interfaces:**
- Consumes: `useDrilldown(cohortId, studentRef)` returning `{ identity: { student_ref, display_name }, domains: [{ domain_id, name, readiness, accuracy }], weak_objectives: [{ objective_id, code, title, readiness }], activity: { last_active, answers_7d, answers_28d, answers_total, accuracy }, live_sessions: [{ session_id, title, held_at, correct, answered }], mocks: { completed, best_score }, suggestions: string[] }`; `useSendAnnouncement` (`send_class_announcement(p_cohort, p_body)` shape: check the generated types for exact arg names and match them); `useLogExport` + `downloadCsv` (kind `csv_drilldown`).

- [ ] **Step 1: Failing test:** mocked drilldown; assert display name heading, weakest domain listed first, each suggestion renders with a "Message class" action, and clicking it opens the announcement dialog prefilled with the suggestion text.
- [ ] **Step 2: Implement.** Header (display name, readiness summary), DomainBars reuse, weak objectives list, activity stats, live-session history table, mock summary, suggestions as action cards: "Message class" opens a Radix dialog prefilled with the suggestion (faculty edits then sends via `useSendAnnouncement`; announcements go to the whole class, per-student messaging is out of scope and the dialog says so). CSV export of the drill-down.
- [ ] **Step 3: Verify + commit.** `git commit -m "Web app: per-student drill-down with actionable next steps"`

---

### Task 8: Settings tab (policy + staff)

**Files:**
- Create: `web/src/components/PolicyEditor.tsx`, `web/src/components/StaffEditor.tsx`; wire into `ClassPage.tsx` Settings tab
- Test: `web/src/components/settings.test.tsx`

**Interfaces:**
- Consumes: `useReportingPolicy`, `useSetReportingPolicy` (`{ cohortId, resolution, identityDisplay, retentionDays }`), `useAddTa` (`{ cohortId, email }`), `useRemoveTa` (`{ cohortId, userId }`), `useAddCoFaculty` (`{ cohortId, email }`).

- [ ] **Step 1: Failing test:** selecting "Aggregate only" and saving calls `useSetReportingPolicy` with `resolution: 'aggregate_only'`; submitting the TA form calls `useAddTa` with the email; each option shows its plain-language consequence text.
- [ ] **Step 2: Implement.** PolicyEditor: three radio options with consequence copy (per_student: "You see named per-student progress."; pseudonymous: "You see per-student progress under stable pseudonyms, never names."; aggregate_only: "You see class-level statistics only."), identity display select, optional retention days (min 30), save with success `role="status"` message. StaffEditor: co-faculty add (email, notes that the colleague needs a redeemed faculty invite), TA add (email, "TAs can run live sessions and see class aggregates; they never see per-student data."), TA list with remove.
- [ ] **Step 3: Verify + commit.** `git commit -m "Web app: reporting policy and staff management"`

---

### Task 9: Live runner (faculty console)

**Files:**
- Create: real `web/src/routes/LiveRunnerPage.tsx`, `web/src/components/QuestionPicker.tsx`, `web/src/components/Scoreboard.tsx`, `web/src/components/Countdown.tsx`, `web/src/lib/live.ts`
- Modify: `web/src/routes/ClassPage.tsx` (Live tab: past sessions via `useCohortSessions`, "Start a session" button)
- Test: `web/src/lib/live.test.ts`

**Interfaces:**
- Consumes: `useCreateLiveSession` (`create_live_session(p_cohort, p_title, p_question_ids jsonb, p_question_seconds)` returns `{ id, join_code, question_count }`), `useAdvanceLiveSession`, `useEndLiveSession`, `liveReveal`, `liveScoreboard`, `useSessionStats`, `useSessionReport`; question list via `supabase.from('questions').select('id, stem, domain_id, cohort_id').eq('review_status', 'published')` filtered to system bank + this cohort.
- Produces: `web/src/lib/live.ts` pure helpers: `secondsLeft(startedAtIso: string, questionSeconds: number, nowMs: number): number` (clamped >= 0) and `useLiveSession(sessionId)` hook subscribing to Realtime UPDATEs on `live_sessions` row (`supabase.channel('live:'+id).on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'live_sessions', filter: 'id=eq.'+id }, cb)`) with 3s polling fallback; JoinPage (Task 10) reuses both.

- [ ] **Step 1: Failing test** (`live.test.ts`): `secondsLeft('2026-08-21T00:00:00Z', 20, Date.parse('2026-08-21T00:00:07Z'))` is 13; never negative; full when not started (null started_at returns questionSeconds).
- [ ] **Step 2: Implement live.ts, run test green.**
- [ ] **Step 3: Implement the console.** Flow: QuestionPicker (checkbox list grouped by domain, count + duration select, title) -> create -> lobby screen: giant join code, QR (`qrcode.toDataURL` of `https://rkapdi.github.io/politiFace/app/#/join?code=XXXX`), live participant count (Realtime on `live_participants` INSERTs with polling fallback), Start button -> question phase: stem + options + `Countdown` (SVG ring, `aria-live="polite"` at 10/5/0) + live answer counter -> Reveal (correct key highlighted, per-option counts from `liveReveal`, explanation) -> next... -> ended: `useSessionStats` "what to reteach" list + `useSessionReport` table (policy-aware; renders the aggregate-only message when the RPC refuses) + export logged as `session_report`.
- [ ] **Step 4: Verify + typecheck + build. Commit.** `git commit -m "Web app: live session console with QR join and realtime phases"`

---

### Task 10: Guest join page

**Files:**
- Create: real `web/src/routes/JoinPage.tsx`
- Test: `web/src/routes/JoinPage.test.tsx`

**Interfaces:**
- Consumes: `signInAnonymously()`, `joinLiveSessionGuest(code, displayName)` (returns `{ id, title, status, index, total, question_seconds }`), `getLiveQuestion`, `submitLiveAnswer`, `liveReveal`, `liveScoreboard`, `useLiveSession` + `secondsLeft` (Task 9). Reads `?code=` from the hash query to prefill.

- [ ] **Step 1: Failing test:** mocked api: entering code + name calls `signInAnonymously` then `joinLiveSessionGuest('ABC123', 'Alex R')`; a `status: 'lobby'` result shows "You are in. Waiting for your instructor to start."; an invalid-code rejection shows the friendly error in a `role="alert"`.
- [ ] **Step 2: Implement.** Screens: (1) join form (code auto-uppercased, name field, copy: "No account needed. Your name appears on this session's scoreboard only, then it is deleted."); (2) lobby; (3) question: stem + option buttons (single tap, disabled after answer, "Answer is in" confirmation), Countdown; (4) reveal: correct answer + explanation + your result via `liveScoreboard` is_me row; (5) ended: final scoreboard top 10 + your rank + CTA "Keep practicing on the Politiface app" linking to the site. If an existing session token exists but is anonymous, reuse it; never route guests into faculty views (Layout nav hidden on /join).
- [ ] **Step 3: Verify + commit.** `git commit -m "Web app: guest browser join for live sessions"`

---

### Task 11: Deploy to docs/app + CI

**Files:**
- Create: `web/scripts/sync-to-docs.sh`, `.github/workflows/web-ci.yml`, `docs/app/` (build output)
- Modify: `docs/faculty/index.html` (add a small link: "New: the Politiface faculty console (beta)" pointing to `../app/`)

- [ ] **Step 1: sync script**

```bash
#!/usr/bin/env bash
# Build the web app and sync it into docs/app/ (served by GitHub Pages
# from the branch, same deploy path as the rest of the site).
set -euo pipefail
cd "$(dirname "$0")/.."
npm run build
rm -rf ../docs/app
mkdir -p ../docs/app
cp -R dist/. ../docs/app/
touch ../docs/app/.nojekyll 2>/dev/null || true
echo "Synced web/dist -> docs/app"
```

`chmod +x web/scripts/sync-to-docs.sh`. Note: Jekyll processes docs/, so also add `docs/app` to the `exclude:`-free static paths; verify `docs/_config.yml` does not exclude it (if `include`/`exclude` lists exist, ensure `app` is passed through untouched).

- [ ] **Step 2: web-ci workflow**

```yaml
name: web-ci
on:
  push:
    branches: [main, v2-planning]
    paths: ['web/**', '.github/workflows/web-ci.yml']
  pull_request:
    paths: ['web/**', '.github/workflows/web-ci.yml']
jobs:
  web:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: web } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm, cache-dependency-path: web/package-lock.json }
      - run: npm ci
      - run: npm run typecheck
      - run: npm test -- --run
      - run: npm run build
```

- [ ] **Step 3: Run sync, verify the built app loads locally** (`python3 -m http.server` from `docs/` and open `http://localhost:8000/app/`; sign-in screen must render; hash routes work on refresh).
- [ ] **Step 4: Commit** built output + workflow + portal link. `git commit -m "Web app: deploy to docs/app with CI"`

---

### Task 12: Accessibility pass

**Files:**
- Test: `web/src/a11y.test.tsx`
- Modify: whatever the axe findings require; `docs/compliance/` VPAT scaffold note

- [ ] **Step 1: axe tests:** render `SignIn`, `ClassesPage` (mocked data), `JoinPage` join form, and `PolicyEditor` in jsdom and assert `expect(await axe(container)).toHaveNoViolations()` via vitest-axe.
- [ ] **Step 2: Fix all violations.** Also verify by hand: tab order on every page, Escape closes dialogs, countdown announcements are `aria-live="polite"` not `assertive`, charts have text alternatives.
- [ ] **Step 3: Update the VPAT scaffold** (`docs/compliance/`) with a dated note that the new console and join page were built and axe-tested to WCAG 2.1 AA.
- [ ] **Step 4: Commit.** `git commit -m "Web app: WCAG 2.1 AA pass with automated axe checks"`

---

## Explicitly out of scope (backlog)

- politiface.app domain migration (then: browser-history routing, `base` change, Supabase auth redirect URLs).
- Admin view parity (stays in `docs/faculty/` old portal), class creation/invite redemption UI, per-student messaging, per-student practice assignments, Playwright end-to-end suite (needs a seeded test project), captcha on anonymous sign-ins (Supabase recommendation; needs Turnstile wiring in JoinPage), SSO/LTI (Epic 8).
- Old-portal decommission and redirects once view parity is reached.
