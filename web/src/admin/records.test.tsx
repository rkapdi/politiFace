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
  isUnverifiedSignin: (kind: string, title: string) => kind === 'problem' && title.startsWith('signin'),
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
    expect(screen.getByText('(typed email, unverified)')).toBeInTheDocument()
    expect(screen.getByText(/1.3.2 \(33\)/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /move class/i })).toBeDisabled()
    expect(screen.getByText('Coming in 2b')).toBeInTheDocument()
    const grantButton = screen.getByRole('button', { name: /grant instructor access/i })
    await userEvent.click(grantButton)
    expect(screen.getByRole('group', { name: /confirm instructor access/i })).toBeInTheDocument()
    const confirmButton = screen.getByRole('button', { name: /^confirm$/i })
    expect(confirmButton).toHaveFocus()
    await userEvent.click(confirmButton)
    expect(m.setFaculty).toHaveBeenCalledWith({ userId: 'u1', verified: true })
    expect(screen.getByRole('button', { name: /grant instructor access/i })).toHaveFocus()
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
