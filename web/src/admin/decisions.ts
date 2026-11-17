// The decisions queue: every card states its evidence in plain numbers and,
// where the console has one, the action that follows. Rule-based and
// deterministic, like the class pulse: each line traces to a count.
import type { PendingRequest } from '../lib/api'
import type { AdminHome, AdminPicture } from './adminApi'
import { A } from './strings'

export type Decision = {
  key: string
  tag: string
  /** `risk` cards are outlined as well as tinted. */
  tone: 'risk' | 'neutral'
  title: string
  evidence: string[]
  cohortId?: string
  request?: PendingRequest
  /** Send the reader to the requests queue (used when the list did not load). */
  toInvites?: boolean
}

/** A class needs this many students before its shares mean anything. */
const FLOOR = 5
const DAY_MS = 86_400_000

const pct = (n: number, of: number) => Math.round((n / of) * 100)

export function buildDecisions(
  home: AdminHome,
  picture: AdminPicture | undefined,
  requests: PendingRequest[] | undefined,
  nowMs: number,
): Decision[] {
  const out: Decision[] = []

  for (const r of requests ?? []) {
    out.push({
      key: `request-${r.id}`,
      tag: A.home.tagAccess,
      tone: 'neutral',
      title: A.home.requestTitle(r.handle),
      evidence: [`${r.school}, ${r.courses}${r.note ? `. ${r.note}` : ''}`, r.email],
      request: r,
    })
  }

  for (const c of picture?.classes ?? []) {
    if (c.is_demo || c.students < FLOOR) continue
    const quiet = c.practised_7d * 2 < c.students
    const below = c.on_track * 2 < c.students
    if (!quiet && !below) continue
    const evidence: string[] = []
    if (below) evidence.push(A.home.evOnTrack(c.on_track, c.students))
    if (quiet) {
      evidence.push(A.home.evPractised(c.practised_7d, c.students))
      if (c.last_live_at == null) evidence.push(A.home.evNoLive)
      else {
        const days = Math.floor((nowMs - new Date(c.last_live_at).getTime()) / DAY_MS)
        evidence.push(days <= 0 ? A.home.evLiveToday : A.home.evLiveAgo(days))
      }
    }
    out.push({
      key: `class-${c.cohort_id}`,
      tag: quiet ? A.home.tagQuiet : A.home.tagBelow,
      tone: below ? 'risk' : 'neutral',
      title: c.name,
      evidence,
      cohortId: c.cohort_id,
    })
  }

  for (const q of picture?.questions ?? []) {
    const evidence = [A.home.evQuestion(Math.round(q.correct_rate * 100), q.answers)]
    if (q.top_wrong) {
      evidence.push(A.home.evTopWrong(Math.round(q.top_wrong.share * 100), q.top_wrong.key))
    }
    out.push({
      key: `question-${q.question_id}`,
      tag: A.home.tagQuestion,
      tone: 'neutral',
      title: q.stem,
      evidence,
    })
  }

  home.attention.forEach((a, i) => {
    // The request and class cards above already carry these two, with
    // more evidence, whenever their own data loaded.
    if (a.kind === 'requests' && requests) return
    if (a.kind === 'stalled' && picture) return
    out.push({
      key: `attention-${a.kind}-${i}`,
      tag:
        a.kind === 'requests'
          ? A.home.tagAccess
          : a.kind === 'stalled'
            ? A.home.tagQuiet
            : a.kind === 'duplicates'
              ? A.home.tagRoster
              : a.kind === 'signin_failures'
                ? A.home.tagSignin
                : A.home.tagNotice,
      tone: a.severity === 'fail' ? 'risk' : 'neutral',
      title: a.title,
      evidence: [],
      cohortId: a.cohort_id,
      toInvites: a.kind === 'requests',
    })
  })

  return out
}

/** Share of students on track, or null when there are none to count. */
export function onTrackPct(onTrack: number | null, students: number | null): number | null {
  if (onTrack == null || students == null || students === 0) return null
  return pct(onTrack, students)
}
