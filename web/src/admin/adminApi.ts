// Admin console data. All reads and writes are admin-only RPCs; the
// server refuses anyone not in app.admins.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { friendlyMessage } from '../lib/api'

// The email on a failed sign-in is whatever the person typed, before any
// account is confirmed to exist: it is not a verified identity. Shared by
// the Timeline (person/class/session records) and the home activity
// stream, which both surface 'problem' rows from the same ops log.
export function isUnverifiedSignin(kind: string, title: string): boolean {
  return kind === 'problem' && title.startsWith('signin')
}

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
export function hitPath(h: SearchHit): string {
  if (h.kind === 'person') return `/admin/people/${h.id}`
  if (h.kind === 'class') return `/admin/classes/${h.id}`
  return `/admin/sessions/${h.id}`
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

export const useAdminHome = (enabled = true) =>
  useQuery({
    queryKey: ['admin', 'home'],
    queryFn: () => call<AdminHome>('admin_home'),
    refetchInterval: 15_000,
    enabled,
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
    placeholderData: keepPreviousData,
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
    // A session that already ended never changes again; stop polling it.
    refetchInterval: query => (query.state.data?.facts.status === 'ended' ? false : 5_000),
  })
export const useAdminInvites = () =>
  useQuery({
    queryKey: ['admin', 'invites'],
    queryFn: () => call<InviteRow[]>('admin_list_invites_v2'),
  })
export const useAdminAudit = (action?: string) =>
  useQuery({
    queryKey: ['admin', 'audit', action ?? null],
    queryFn: () =>
      call<AuditRow[]>('admin_audit_list', { p_action: action ?? null, p_limit: 200 }),
  })

export const useSetFaculty = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { userId: string; verified: boolean }) =>
      call<void>('admin_set_faculty_audited', {
        p_user: a.userId,
        p_verified: a.verified,
      }),
    onSuccess: (_d, a) => {
      void qc.invalidateQueries({ queryKey: ['admin', 'person', a.userId] })
      void qc.invalidateQueries({ queryKey: ['admin', 'audit'] })
    },
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
