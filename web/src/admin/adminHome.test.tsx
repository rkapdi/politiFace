import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { AdminPicture } from './adminApi'

vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, params, children }: { to: string; params?: Record<string, string>; children: React.ReactNode }) => (
    <a href={`#${Object.entries(params ?? {}).reduce((p, [k, v]) => p.replace(`$${k}`, v), to)}`}>{children}</a>
  ),
  useSearch: () => ({ q: 'maria' }),
}))

const days = (onTrack: (number | null)[]): AdminPicture['days'] =>
  onTrack.map((o, i) => ({
    day: `2026-10-${String(i + 1).padStart(2, '0')}`,
    answers: i === 13 ? 40 : 10 + i,
    practising: 5,
    live_sessions: i % 5 === 0 ? 2 : 0,
    actions: i === 3 ? 1 : 0,
    students: o == null ? null : 200,
    on_track: o,
  }))

const picture: AdminPicture = {
  tz: 'UTC',
  now: { students: 200, on_track: 142, practised_7d: 162, live_7d: 134 },
  classes: [
    { cohort_id: 'c1', name: 'Section A', term: '2026F', is_demo: false, students: 40, on_track: 31, practised_7d: 22, last_live_at: '2026-10-03T15:00:00Z' },
    { cohort_id: 'c2', name: 'Section B', term: '2026F', is_demo: false, students: 30, on_track: 12, practised_7d: 6, last_live_at: null },
    { cohort_id: 'c3', name: 'Demo class', term: null, is_demo: true, students: 8, on_track: 0, practised_7d: 0, last_live_at: null },
  ],
  // Snapshots began seven days ago at 136 of 200 (68%).
  days: days([null, null, null, null, null, null, 136, 136, 138, 138, 140, 140, 141, 141]),
  questions: [
    { question_id: 'q1', stem: 'Which branch ratifies treaties?', answers: 64, correct_rate: 0.219, top_wrong: { key: 'B', share: 0.5 } },
  ],
}

const h = vi.hoisted(() => ({
  picture: undefined as unknown,
  pictureError: null as Error | null,
  requests: [] as unknown[],
  decide: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  useFacultyRequests: () => ({ data: h.requests }),
  useDecideFacultyRequest: () => ({ mutate: h.decide, isPending: false, error: null }),
}))
vi.mock('./adminApi', () => ({
  isUnverifiedSignin: (kind: string, title: string) => kind === 'problem' && title.startsWith('signin'),
  hitPath: (hit: { kind: string; id: string }) =>
    hit.kind === 'person'
      ? `/admin/people/${hit.id}`
      : hit.kind === 'class'
        ? `/admin/classes/${hit.id}`
        : `/admin/sessions/${hit.id}`,
  useAdminHome: () => ({
    data: {
      totals: { people: 297, students: 212, faculty: 3, classes: 9, answered_live_7d: 171 },
      live_now: [
        { session_id: 's1', title: 'Week 3 review', cohort_id: 'c1', class: 'Section A', professor: 'Rivera Demo', status: 'question', index: 3, total: 8, participants: 38, created_at: '2026-10-04T15:02:00Z' },
        { session_id: 's2', title: 'Pop quiz', cohort_id: 'c1', class: 'Section A', professor: 'Rivera Demo', status: 'lobby', index: -1, total: 5, participants: 2, created_at: '2026-10-04T15:10:00Z' },
      ],
      pending_requests: 2,
      funnel: [{ cohort_id: 'c1', name: 'Section A', term: '2026F', members: 41, students: 40, answered_live: 38, practiced_7d: 22 }],
      attention: [
        { kind: 'requests', severity: 'warn', title: '2 instructor request(s) pending' },
        { kind: 'stalled', severity: 'warn', cohort_id: 'c2', title: 'Section B: 6 of 30 students active this week' },
        { kind: 'signin_failures', severity: 'fail', title: '14 sign-in failures in the last hour' },
      ],
      health: { run_at: '2026-10-04T06:07:00Z', ok: true, failures: [] },
    },
    isPending: false,
    error: null,
  }),
  useAdminPicture: () => ({
    data: h.picture,
    isPending: false,
    error: h.pictureError,
  }),
  useAdminOnline: () => ({
    data: {
      total: 3, ios: 2, web: 1, guests: 1,
      people: [{ user_id: 'u9', name: 'Ana Ruiz', clients: ['ios'], app_version: '1.3.2 (34)', last_seen_at: '2026-10-06T15:06:12Z' }],
    },
  }),
  useAdminActivity: () => ({
    data: [
      { at: '2026-10-04T15:06:12Z', kind: 'live_join', severity: 'ok', title: 'Maria Lopez joined live: Week 3 review', user_id: 'u1', cohort_id: 'c1', session_id: 's1' },
      { at: '2026-10-04T15:05:40Z', kind: 'problem', severity: 'fail', title: 'signin send failed: 429 (maria@students.example.edu)', user_id: null, cohort_id: null, session_id: null },
    ],
    isPending: false,
  }),
  useAdminSearch: () => ({ data: [{ kind: 'person', id: 'u1', title: 'Maria Lopez', subtitle: 'maria@students.example.edu · user_1' }], isPending: false }),
}))

import { AdminHome } from './AdminHome'
import { SearchPage } from './SearchPage'
import { buildDecisions } from './decisions'

beforeEach(() => {
  h.picture = picture
  h.pictureError = null
  h.requests = []
  h.decide.mockClear()
})

describe('AdminHome', () => {
  it('leads with the on-track number and the facts behind it', () => {
    render(<AdminHome />)
    const outcome = within(screen.getByRole('region', { name: 'On track to pass' }))
    // Once as the headline, once as the third fact behind it.
    expect(outcome.getAllByText('71%')).toHaveLength(2)
    expect(outcome.getByText('142 of 200 students project above the pass line.')).toBeInTheDocument()
    // 71% now against the 68% snapshot from seven days ago.
    expect(outcome.getByText('+3 pts in 7 days')).toBeInTheDocument()
    expect(outcome.getByText('81%')).toBeInTheDocument()
    expect(outcome.getByText('67%')).toBeInTheDocument()
    expect(outcome.getByText('297 people, 9 classes, 3 instructors')).toBeInTheDocument()
  })

  it('lists classes weakest first, flags the ones under half, and keeps demo classes last', () => {
    render(<AdminHome />)
    const classes = within(screen.getByRole('region', { name: 'Classes' }))
    const names = classes.getAllByRole('link').map(a => a.textContent)
    expect(names).toEqual(['Section B', 'Section A', 'Demo class'])
    expect(classes.getByRole('link', { name: 'Section A' })).toHaveAttribute('href', '#/admin/classes/c1')
    expect(classes.getByText('40%')).toBeInTheDocument()
    expect(classes.getByText('under half on track')).toBeInTheDocument()
    expect(classes.getByText('demo')).toBeInTheDocument()
  })

  it('describes each timeline lane in words', () => {
    render(<AdminHome />)
    expect(screen.getByRole('img', { name: /^Answers: 248 in the last 14 days, most on .+ \(40\)\.$/ })).toBeInTheDocument()
    expect(screen.getByRole('img', { name: /^Live sessions: 6 in the last 14 days/ })).toBeInTheDocument()
    expect(screen.getByRole('img', { name: 'On track: 68% to 71% over 8 days.' })).toBeInTheDocument()
    expect(screen.getByRole('img', { name: /^Actions: 1 in the last 14 days/ })).toBeInTheDocument()
  })

  it('turns classes, questions and alerts into decisions with their evidence', () => {
    render(<AdminHome />)
    const decisions = within(screen.getByRole('region', { name: 'Decisions' }))
    expect(decisions.getByText('3 open')).toBeInTheDocument()
    expect(decisions.getByText('Class going quiet')).toBeInTheDocument()
    expect(decisions.getByText('12 of 30 students project above the pass line.')).toBeInTheDocument()
    expect(decisions.getByText('6 of 30 students practised this week.')).toBeInTheDocument()
    expect(decisions.getByText('No live session yet.')).toBeInTheDocument()
    expect(decisions.getByRole('link', { name: 'Open class' })).toHaveAttribute('href', '#/admin/classes/c2')
    expect(decisions.getByText('Which branch ratifies treaties?')).toBeInTheDocument()
    expect(decisions.getByText('22% correct from 64 answers in 60 days.')).toBeInTheDocument()
    expect(decisions.getByText('50% chose B.')).toBeInTheDocument()
    expect(decisions.getByText('14 sign-in failures in the last hour')).toBeInTheDocument()
    // Covered by the class card above, with more evidence.
    expect(decisions.queryByText(/students active this week/)).toBeNull()
  })

  it('approves an access request from the queue', async () => {
    h.requests = [
      { id: 'r1', user_id: 'u5', handle: 'prof_lee', email: 'lee@college.example.edu', school: 'Example College', courses: 'GOVT 2305', note: null, created_at: '2026-10-04T12:00:00Z' },
    ]
    render(<AdminHome />)
    expect(screen.getByText('prof_lee asks for instructor access')).toBeInTheDocument()
    expect(screen.getByText('Example College, GOVT 2305')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Approve' }))
    expect(h.decide).toHaveBeenCalledWith({ id: 'r1', approve: true })
  })

  it('still works before the server has the picture function', () => {
    h.picture = undefined
    h.pictureError = new Error('function admin_picture does not exist')
    render(<AdminHome />)
    expect(screen.getByText('The on-track number is not available yet.')).toBeInTheDocument()
    expect(screen.getByText('The 14-day picture is not available yet.')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Section A' })).toHaveAttribute('href', '#/admin/classes/c1')
    // Without the picture, the server's own alert stands in for the class card.
    expect(screen.getByText('Section B: 6 of 30 students active this week')).toBeInTheDocument()
  })

  it('shows live sessions, who is online, and the activity stream', () => {
    render(<AdminHome />)
    expect(screen.getByText('Week 3 review')).toBeInTheDocument()
    expect(screen.getByText(/Q4\/8/)).toBeInTheDocument()
    expect(screen.getByText('Pop quiz')).toBeInTheDocument()
    expect(screen.getByText(/Lobby/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Ana Ruiz' })).toHaveAttribute('href', '#/admin/people/u9')
    expect(screen.getByText(/iOS 1\.3\.2 \(34\)/)).toBeInTheDocument()
    expect(screen.getByText(/1 guest/)).toBeInTheDocument()
    expect(screen.getByText(/signin send failed/)).toBeInTheDocument()
    expect(screen.getByText('(typed email, unverified)')).toBeInTheDocument()
    expect(screen.getByText('problem')).toHaveClass('sev-fail')
  })
})

describe('buildDecisions', () => {
  const home = {
    totals: { people: 1, students: 1, faculty: 1, classes: 1, answered_live_7d: 0 },
    live_now: [],
    pending_requests: 0,
    funnel: [],
    attention: [],
    health: null,
  }
  const klass = (over: Partial<AdminPicture['classes'][number]>) => ({
    cohort_id: 'c', name: 'Section C', term: null, is_demo: false,
    students: 20, on_track: 15, practised_7d: 15, last_live_at: null, ...over,
  })
  const withClass = (over: Partial<AdminPicture['classes'][number]>) =>
    buildDecisions(home, { ...picture, questions: [], classes: [klass(over)] }, [], Date.parse('2026-10-20T12:00:00Z'))

  it('leaves healthy, tiny and demo classes alone', () => {
    expect(withClass({})).toEqual([])
    expect(withClass({ students: 4, on_track: 0, practised_7d: 0 })).toEqual([])
    expect(withClass({ is_demo: true, on_track: 0, practised_7d: 0 })).toEqual([])
  })

  it('counts whole days since the last live session', () => {
    const [d] = withClass({ practised_7d: 3, last_live_at: '2026-10-04T12:00:00Z' })
    expect(d.tag).toBe('Class going quiet')
    expect(d.tone).toBe('neutral')
    expect(d.evidence).toEqual(['3 of 20 students practised this week.', 'Last live session 16 days ago.'])
  })

  it('outlines a class that is below the pass line even when it is active', () => {
    const [d] = withClass({ on_track: 9 })
    expect(d.tag).toBe('Below the pass line')
    expect(d.tone).toBe('risk')
    expect(d.evidence).toEqual(['9 of 20 students project above the pass line.'])
  })
})

describe('SearchPage', () => {
  it('lists hits linking to their records', () => {
    render(<SearchPage />)
    expect(screen.getByRole('link', { name: /Maria Lopez/ })).toHaveAttribute('href', '#/admin/people/u1')
  })
})
