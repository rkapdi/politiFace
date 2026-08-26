// The typed data layer. Every metric the app shows comes from a spine RPC;
// nothing is computed client-side. Server raise texts are mapped to plain
// sentences here, once.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from './supabase'
import type { Database, Json } from './database.types'

type Fns = Database['public']['Functions']

export type ClassOverviewRow = Fns['my_faculty_overview']['Returns'][number]
export type CohortOverview = Fns['cohort_overview']['Returns'][number]
export type DomainStatRow = Fns['cohort_domain_stats']['Returns'][number]
export type TopMissRow = Fns['cohort_top_misses']['Returns'][number]
export type TrendRow = Fns['cohort_engagement_trend']['Returns'][number]
export type AtRiskRow = Fns['at_risk_students']['Returns'][number]
export type ProgressRow = Fns['cohort_student_progress']['Returns'][number]
export type SessionRow = Fns['cohort_live_sessions']['Returns'][number]
export type SessionStatRow = Fns['live_session_stats']['Returns'][number]
export type SessionReportRow = Fns['live_session_report']['Returns'][number]

export type ReportingPolicy = {
  resolution: 'per_student' | 'pseudonymous' | 'aggregate_only'
  identity_display: 'roster' | 'display_name' | 'pseudonym'
  raw_retention_days: number | null
  effective: 'per_student' | 'pseudonymous' | 'aggregate_only'
}

export type Drilldown = {
  identity: { student_ref: string; display_name: string }
  domains: {
    domain_id: number
    name: string
    readiness: number | null
    accuracy: number | null
  }[]
  weak_objectives: {
    objective_id: string
    code: string
    title: string
    readiness: number
  }[]
  activity: {
    last_active: string | null
    answers_7d: number
    answers_28d: number
    answers_total: number
    accuracy: number
  }
  live_sessions: {
    session_id: string
    title: string
    held_at: string
    correct: number
    answered: number
  }[]
  mocks: { completed: number; best_score: number | null }
  suggestions: string[]
}

export type LiveJoin = {
  id: string
  title: string
  status: 'lobby' | 'question' | 'reveal' | 'ended'
  index: number
  total: number
  question_seconds: number
}

export type LiveQuestion = {
  status: 'lobby' | 'question' | 'reveal' | 'ended'
  index?: number
  total?: number
  question_seconds?: number
  started_at?: string | null
  question?: {
    id: string
    stem: string
    options: { key: string; text: string }[]
  }
}

export type LiveRevealData = {
  question_id: string
  correct_key: string
  explanation: string | null
  counts: Record<string, number>
}

export type ScoreboardRow = {
  rank: number
  handle: string
  score: number
  correct_count: number
  is_me: boolean
}

const FRIENDLY: Record<string, string> = {
  'this class reports aggregate data only':
    'This class reports aggregate data only, so per-student views are off.',
  'not faculty of this cohort':
    'Your account does not have faculty access to this class.',
  'invalid or ended session code':
    'That code does not match a running session. Check it with your instructor.',
  'enter a display name (2 to 40 characters)':
    'Enter a display name between 2 and 40 characters.',
  'this session is limited to class members':
    'This session is limited to class members. Join the class in the app first.',
  'question is not open': 'That question just closed.',
  'time is up': 'Time is up for this question.',
  'no Politiface account uses that email':
    'No Politiface account uses that email. They need to sign in to the app or console once first.',
  'that account has not redeemed a faculty invite code yet':
    'That account has not redeemed a faculty invite code yet.',
  'instructor verification required':
    'Creating classes requires instructor verification. Redeem a faculty invite code in the app or portal first.',
  'class name too short': 'Class names need at least 3 characters.',
}

export function friendlyMessage(error: { message: string }): string {
  return FRIENDLY[error.message] ?? 'Something went wrong on our side. Try again.'
}

type FnName = keyof Fns & string

async function rpc<T>(fn: FnName, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(
    fn as never,
    args as never,
  )
  if (error) throw new Error(friendlyMessage(error))
  return data as T
}

// ── plain fetchers (also used outside hooks: guest flow, live loops) ────────
export const myClasses = () =>
  rpc<ClassOverviewRow[]>('my_faculty_overview')
export const myCohortRole = (cohortId: string) =>
  rpc<'student' | 'faculty' | 'ta' | null>('my_cohort_role', { p_cohort: cohortId })
export const reportingPolicy = (cohortId: string) =>
  rpc<ReportingPolicy>('get_reporting_policy', { p_cohort: cohortId })
export const cohortOverview = (cohortId: string) =>
  rpc<CohortOverview[]>('cohort_overview', { p_cohort: cohortId }).then(r => r[0])
export const domainStats = (cohortId: string) =>
  rpc<DomainStatRow[]>('cohort_domain_stats', { p_cohort: cohortId })
export const topMisses = (cohortId: string) =>
  rpc<TopMissRow[]>('cohort_top_misses', { p_cohort: cohortId })
export const engagementTrend = (cohortId: string, days: number) =>
  rpc<TrendRow[]>('cohort_engagement_trend', { p_cohort: cohortId, p_days: days })
export const atRiskStudents = (cohortId: string, threshold: number) =>
  rpc<AtRiskRow[]>('at_risk_students', { p_cohort: cohortId, p_threshold: threshold })
export const studentProgress = (cohortId: string) =>
  rpc<ProgressRow[]>('cohort_student_progress', { p_cohort: cohortId })
export const studentDrilldown = (cohortId: string, studentRef: string) =>
  rpc<Drilldown>('student_drilldown', {
    p_cohort: cohortId,
    p_student_ref: studentRef,
  })
export const cohortSessions = (cohortId: string) =>
  rpc<SessionRow[]>('cohort_live_sessions', { p_cohort: cohortId })
export const sessionStats = (sessionId: string) =>
  rpc<SessionStatRow[]>('live_session_stats', { p_session: sessionId })
export const sessionReport = (sessionId: string) =>
  rpc<SessionReportRow[]>('live_session_report', { p_session: sessionId })
export const getLiveQuestion = (sessionId: string) =>
  rpc<LiveQuestion>('get_live_question', { p_session: sessionId })
export const submitLiveAnswer = (
  sessionId: string,
  questionId: string,
  key: string,
) =>
  rpc<{ accepted: boolean }>('submit_live_answer', {
    p_session: sessionId,
    p_question: questionId,
    p_key: key,
  })
export const liveReveal = (sessionId: string) =>
  rpc<LiveRevealData>('live_reveal', { p_session: sessionId })
export const liveScoreboard = (sessionId: string) =>
  rpc<ScoreboardRow[]>('live_scoreboard', { p_session: sessionId })
export const joinLiveSessionGuest = (code: string, displayName: string) =>
  rpc<LiveJoin>('join_live_session_guest', {
    p_code: code,
    p_display_name: displayName,
  })
// First sign-in bootstrapping: the console needs a profiles row (RLS lets
// a user insert only their own). Handle is auto-generated; users can
// change it in the app later.
export const ensureProfile = async (userId: string): Promise<void> => {
  const existing = await supabase
    .from('profiles')
    .select('id')
    .eq('id', userId)
    .maybeSingle()
  if (existing.error || existing.data) return
  await supabase.from('profiles').insert({
    id: userId,
    handle: `user_${userId.replace(/-/g, '').slice(0, 8)}`,
  })
}

export const createCohort = (name: string, term: string | null) =>
  rpc<{ id: string; join_code: string }>('create_cohort', {
    p_name: name,
    p_term: term,
  })

export const signInAnonymously = async () => {
  const { data, error } = await supabase.auth.signInAnonymously()
  if (error) throw new Error(friendlyMessage(error))
  return data
}

export type PulseCardData = {
  kind: 'at_risk' | 'weak_domain' | 'participation'
  headline: string
  detail: string
}

export type CohortPulse = {
  below_floor?: boolean
  students: number
  active_7d?: number
  above_line?: number
  at_risk?: number
  model_version?: string
  sentence: string
  cards: PulseCardData[]
}

export type CohortDistribution = {
  below_floor?: boolean
  students: number
  bins?: Record<string, number>
  avg?: number
  above_line?: number
  pass_line: number
  model_version?: string
}

export const cohortPulse = (cohortId: string) =>
  rpc<CohortPulse>('cohort_pulse', { p_cohort: cohortId })
export const cohortDistribution = (cohortId: string) =>
  rpc<CohortDistribution>('cohort_distribution', { p_cohort: cohortId })

export type TaRow = { user_id: string; display: string }

// TAs on a cohort: membership rows are member-readable under RLS; handles
// come from profiles (co-cohort members may read them).
export const cohortTas = async (cohortId: string): Promise<TaRow[]> => {
  const members = await supabase
    .from('cohort_members')
    .select('user_id, roster_name')
    .eq('cohort_id', cohortId)
    .eq('role', 'ta')
  if (members.error) throw new Error(friendlyMessage(members.error))
  const rows = members.data ?? []
  if (rows.length === 0) return []
  const profiles = await supabase
    .from('profiles')
    .select('id, handle')
    .in('id', rows.map(r => r.user_id))
  if (profiles.error) throw new Error(friendlyMessage(profiles.error))
  const handles = new Map((profiles.data ?? []).map(p => [p.id, p.handle]))
  return rows.map(r => ({
    user_id: r.user_id,
    display: r.roster_name ?? handles.get(r.user_id) ?? r.user_id,
  }))
}

export type PickableQuestion = {
  id: string
  stem: string
  domain_id: number
  cohort_id: string | null
}

// Published questions a session may draw from: the system bank plus this
// cohort's own faculty-authored items (RLS enforces the same rule server-side).
export const pickableQuestions = async (
  cohortId: string,
): Promise<PickableQuestion[]> => {
  const { data, error } = await supabase
    .from('questions')
    .select('id, stem, domain_id, cohort_id')
    .eq('review_status', 'published')
    .or(`cohort_id.is.null,cohort_id.eq.${cohortId}`)
    .order('domain_id')
  if (error) throw new Error(friendlyMessage(error))
  return data ?? []
}

export type DomainRow = { id: number; code: string; name: string }

export const domains = async (): Promise<DomainRow[]> => {
  const { data, error } = await supabase
    .from('domains')
    .select('id, code, name')
    .order('ordinal')
  if (error) throw new Error(friendlyMessage(error))
  return data ?? []
}

export type LiveSessionMeta = {
  id: string
  title: string
  status: string
  join_code: string
  question_seconds: number
}

export const liveSessionMeta = async (
  sessionId: string,
): Promise<LiveSessionMeta> => {
  const { data, error } = await supabase
    .from('live_sessions')
    .select('id, title, status, join_code, question_seconds')
    .eq('id', sessionId)
    .single()
  if (error) throw new Error(friendlyMessage(error))
  return data
}

export const participantCount = async (sessionId: string): Promise<number> => {
  const { count, error } = await supabase
    .from('live_participants')
    .select('*', { count: 'exact', head: true })
    .eq('session_id', sessionId)
  if (error) throw new Error(friendlyMessage(error))
  return count ?? 0
}

// ── query hooks ─────────────────────────────────────────────────────────────
export const useCohortPulse = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'pulse'],
    queryFn: () => cohortPulse(cohortId),
  })
export const useCohortDistribution = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'distribution'],
    queryFn: () => cohortDistribution(cohortId),
  })
export const usePickableQuestions = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'pickable'],
    queryFn: () => pickableQuestions(cohortId),
  })
export const useDomains = () =>
  useQuery({ queryKey: ['domains'], queryFn: domains, staleTime: Infinity })
export const useLiveSessionMeta = (sessionId: string) =>
  useQuery({
    queryKey: ['session', sessionId, 'meta'],
    queryFn: () => liveSessionMeta(sessionId),
  })
export const useParticipantCount = (sessionId: string, enabled: boolean) =>
  useQuery({
    queryKey: ['session', sessionId, 'participants'],
    queryFn: () => participantCount(sessionId),
    enabled,
    refetchInterval: 3000,
  })
export const useCohortTas = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'tas'],
    queryFn: () => cohortTas(cohortId),
  })
export const useMyClasses = () =>
  useQuery({ queryKey: ['classes'], queryFn: myClasses })
export const useCohortRole = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'role'],
    queryFn: () => myCohortRole(cohortId),
  })
export const useReportingPolicy = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'policy'],
    queryFn: () => reportingPolicy(cohortId),
  })
export const useCohortOverview = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'overview'],
    queryFn: () => cohortOverview(cohortId),
  })
export const useDomainStats = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'domains'],
    queryFn: () => domainStats(cohortId),
  })
export const useTopMisses = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'misses'],
    queryFn: () => topMisses(cohortId),
  })
export const useEngagementTrend = (cohortId: string, days = 28) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'trend', days],
    queryFn: () => engagementTrend(cohortId, days),
  })
export const useAtRisk = (cohortId: string, threshold = 0.6) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'at-risk', threshold],
    queryFn: () => atRiskStudents(cohortId, threshold),
  })
export const useStudentProgress = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'progress'],
    queryFn: () => studentProgress(cohortId),
  })
export const useDrilldown = (cohortId: string, studentRef: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'student', studentRef],
    queryFn: () => studentDrilldown(cohortId, studentRef),
  })
export const useCohortSessions = (cohortId: string) =>
  useQuery({
    queryKey: ['cohort', cohortId, 'sessions'],
    queryFn: () => cohortSessions(cohortId),
  })
export const useSessionStats = (sessionId: string, enabled = true) =>
  useQuery({
    queryKey: ['session', sessionId, 'stats'],
    queryFn: () => sessionStats(sessionId),
    enabled,
  })
export const useSessionReport = (sessionId: string, enabled = true) =>
  useQuery({
    queryKey: ['session', sessionId, 'report'],
    queryFn: () => sessionReport(sessionId),
    enabled,
    retry: false,
  })

// ── mutations ───────────────────────────────────────────────────────────────
function useCohortMutation<A>(fn: (args: A) => Promise<unknown>, cohortKeyOf: (args: A) => string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: fn,
    onSuccess: (_data, args) => {
      void qc.invalidateQueries({ queryKey: ['cohort', cohortKeyOf(args)] })
    },
  })
}

export const useCreateCohort = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { name: string; term: string | null }) =>
      createCohort(a.name, a.term),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['classes'] }),
  })
}

export const useSetReportingPolicy = () =>
  useCohortMutation(
    (a: {
      cohortId: string
      resolution: ReportingPolicy['resolution']
      identityDisplay: ReportingPolicy['identity_display']
      retentionDays?: number | null
    }) =>
      rpc('set_reporting_policy', {
        p_cohort: a.cohortId,
        p_resolution: a.resolution,
        p_identity_display: a.identityDisplay,
        p_retention_days: a.retentionDays ?? null,
      }),
    a => a.cohortId,
  )

export const useLogExport = () => {
  return useMutation({
    mutationFn: (a: {
      cohortId: string
      kind:
        | 'csv_progress'
        | 'csv_at_risk'
        | 'csv_drilldown'
        | 'one_pager'
        | 'session_report'
    }) => rpc('log_report_export', { p_cohort: a.cohortId, p_kind: a.kind }),
  })
}

export const useAddTa = () =>
  useCohortMutation(
    (a: { cohortId: string; email: string }) =>
      rpc('add_cohort_ta', { p_cohort: a.cohortId, p_email: a.email }),
    a => a.cohortId,
  )

export const useRemoveTa = () =>
  useCohortMutation(
    (a: { cohortId: string; userId: string }) =>
      rpc('remove_cohort_ta', { p_cohort: a.cohortId, p_user: a.userId }),
    a => a.cohortId,
  )

export const useAddCoFaculty = () =>
  useCohortMutation(
    (a: { cohortId: string; email: string }) =>
      rpc('add_co_faculty', { p_cohort: a.cohortId, p_email: a.email }),
    a => a.cohortId,
  )

export const useSendAnnouncement = () => {
  return useMutation({
    mutationFn: (a: { cohortId: string; body: string }) =>
      rpc('send_class_announcement', {
        p_cohort: a.cohortId,
        p_body: a.body,
      }),
  })
}

export const useCreateLiveSession = () =>
  useCohortMutation(
    (a: {
      cohortId: string
      title: string
      questionIds: string[]
      questionSeconds: number
    }) =>
      rpc<{ id: string; join_code: string; question_count: number }>(
        'create_live_session',
        {
          p_cohort: a.cohortId,
          p_title: a.title,
          p_question_ids: a.questionIds as unknown as Json,
          p_question_seconds: a.questionSeconds,
        },
      ),
    a => a.cohortId,
  )

export const useAdvanceLiveSession = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { sessionId: string }) =>
      rpc<{ status: string; index?: number; total?: number }>(
        'advance_live_session',
        { p_session: a.sessionId },
      ),
    onSuccess: (_d, a) => {
      void qc.invalidateQueries({ queryKey: ['session', a.sessionId] })
    },
  })
}

export const useEndLiveSession = () => {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (a: { sessionId: string }) =>
      rpc('end_live_session', { p_session: a.sessionId }),
    onSuccess: (_d, a) => {
      void qc.invalidateQueries({ queryKey: ['session', a.sessionId] })
    },
  })
}
