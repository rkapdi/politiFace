import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'

vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, params, children }: { to: string; params?: Record<string, string>; children: React.ReactNode }) => (
    <a href={`#${Object.entries(params ?? {}).reduce((p, [k, v]) => p.replace(`$${k}`, v), to)}`}>{children}</a>
  ),
  useSearch: () => ({ q: 'maria' }),
}))
const h = vi.hoisted(() => ({
  health: { run_at: '2026-10-04T06:07:00Z', ok: true, failures: [] } as
    | { run_at: string; ok: boolean; failures: unknown }
    | null,
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
      live_now: [{ session_id: 's1', title: 'Week 3 review', cohort_id: 'c1', class: 'Section A', professor: 'Purcell Demo', status: 'question', index: 3, total: 8, participants: 38, created_at: '2026-10-04T15:02:00Z' }],
      pending_requests: 2,
      funnel: [{ cohort_id: 'c1', name: 'Section A', term: '2026F', members: 41, students: 40, answered_live: 38, practiced_7d: 22 }],
      attention: [{ kind: 'signin_failures', severity: 'fail', title: '14 sign-in failures in the last hour' }],
      health: h.health,
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
    h.health = { run_at: '2026-10-04T06:07:00Z', ok: true, failures: [] }
    render(<AdminHome />)
    expect(screen.getByText('212')).toBeInTheDocument()
    expect(screen.getByText('Week 3 review')).toBeInTheDocument()
    expect(screen.getByText(/Q4\/8/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Section A' })).toHaveAttribute('href', '#/admin/classes/c1')
    expect(screen.getByText('14 sign-in failures in the last hour')).toHaveClass('sev-fail')
    expect(screen.getByText(/signin send failed/)).toBeInTheDocument()
    expect(screen.getByText('(typed email, unverified)')).toBeInTheDocument()
    expect(screen.getByText('NOMINAL')).toBeInTheDocument()
  })

  it('shows UNKNOWN when no health check has run yet', () => {
    h.health = null
    render(<AdminHome />)
    expect(screen.getByText('UNKNOWN')).toBeInTheDocument()
    expect(screen.queryByText('NOMINAL')).toBeNull()
  })
})

describe('SearchPage', () => {
  it('lists hits linking to their records', () => {
    render(<SearchPage />)
    expect(screen.getByRole('link', { name: /Maria Lopez/ })).toHaveAttribute('href', '#/admin/people/u1')
  })
})
