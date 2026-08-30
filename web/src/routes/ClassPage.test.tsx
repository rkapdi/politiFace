import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'

vi.mock('../lib/api', () => ({
  useCohortOverview: () => ({
    data: { students: 32, active_7d: 21, answers_total: 480, mocks_completed: 12 },
    isPending: false,
    error: null,
  }),
  useDomainStats: () => ({
    data: [
      { domain_code: 'D1', domain_name: 'American Democracy', students: 30, answers: 200, accuracy: 0.62 },
      { domain_code: 'D2', domain_name: 'U.S. Constitution', students: 28, answers: 150, accuracy: 0.55 },
    ],
    isPending: false,
    error: null,
  }),
  useTopMisses: () => ({
    data: [
      { question_id: 'q1', stem: 'Which article establishes the judiciary?', domain_code: 'D2', students: 20, attempts: 41, miss_rate: 0.7 },
    ],
    isPending: false,
    error: null,
  }),
  useEngagementTrend: () => ({
    data: [
      { day: '2026-08-20', active_students: 10, answers: 50 },
      { day: '2026-08-21', active_students: 12, answers: 61 },
    ],
    isPending: false,
    error: null,
  }),
  useReportingPolicy: () => ({
    data: {
      resolution: 'aggregate_only',
      identity_display: 'pseudonym',
      raw_retention_days: null,
      effective: 'aggregate_only',
    },
    isPending: false,
    error: null,
  }),
  useCohortRole: () => ({ data: 'ta', isPending: false, error: null }),
  useLogExport: () => ({ mutate: vi.fn() }),
  useCohortPulse: () => ({
    data: {
      students: 32,
      above_line: 18,
      at_risk: 14,
      sentence:
        '18 of 32 students project above the pass line. U.S. Constitution is the weakest domain at 46%. 12 of 32 practiced this week.',
      cards: [
        {
          kind: 'at_risk',
          headline: '14 students project below the pass line',
          detail: 'The Students tab ranks them lowest readiness first.',
        },
      ],
    },
    isPending: false,
    error: null,
  }),
  useCohortDistribution: () => ({
    data: {
      students: 32,
      bins: { '40-49': 10, '50-59': 12 },
      avg: 49.5,
      above_line: 18,
      pass_line: 48,
    },
    isPending: false,
    error: null,
  }),
  useAtRisk: () => ({ data: [], isPending: false, error: null }),
  useStudentProgress: () => ({ data: [], isPending: false, error: null }),
  useCohortSessions: () => ({ data: [], isPending: false, error: null }),
  useSendAnnouncement: () => ({ mutate: vi.fn(), isPending: false }),
}))

import { ClassView } from './ClassPage'

describe('ClassView overview', () => {
  it('renders stats, domain bars, and the aggregate-only policy banner', () => {
    render(<ClassView cohortId="c1" />)
    expect(screen.getByText('32')).toBeInTheDocument()
    expect(screen.getByText('480')).toBeInTheDocument()
    expect(
      screen.getByRole('img', { name: /American Democracy, 62 percent accuracy/i }),
    ).toBeInTheDocument()
    expect(screen.getByText(/aggregate data only/i)).toBeInTheDocument()
    expect(screen.getByText(/judiciary/)).toBeInTheDocument()
    // TA callers never see the Settings tab.
    expect(screen.queryByRole('tab', { name: /settings/i })).toBeNull()
    // The pulse leads, and its at-risk card routes to the Students tab.
    expect(
      screen.getByText(/18 of 32 students project above the pass line/),
    ).toBeInTheDocument()
    expect(screen.getByText(/pass line 48/i)).toBeInTheDocument()
  })

  it('pulse card action switches to the Students tab', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    render(<ClassView cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /see who/i }))
    expect(
      screen.getByRole('tab', { name: /students/i }),
    ).toHaveAttribute('aria-selected', 'true')
  })
})
