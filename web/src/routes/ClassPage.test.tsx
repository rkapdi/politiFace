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
  })
})
