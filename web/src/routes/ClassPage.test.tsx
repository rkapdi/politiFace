import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'

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
  useCohortInfo: () => ({
    data: { name: 'POS 2041-67', term: '2026F', join_code: 'K7QX2M' },
    isPending: false,
    error: null,
  }),
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
  usePickableQuestions: () => ({
    data: [
      { id: 'q1', stem: 'Which article establishes the judiciary?', domain_id: 2, cohort_id: null },
    ],
    isPending: false,
    error: null,
  }),
  useDomains: () => ({
    data: [{ id: 2, name: 'U.S. Constitution' }],
    isPending: false,
    error: null,
  }),
  useCreateLiveSession: () => ({ mutate: vi.fn(), isPending: false, error: null }),
}))

vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: async () => ({
        data: { session: { access_token: 'test-token' } },
      }),
    },
  },
}))

import { ClassView } from './ClassPage'

describe('ClassView overview', () => {
  it('shows the class name and the join code professors hand out', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    const writeText = vi.fn(async () => undefined)
    Object.assign(navigator, { clipboard: { writeText } })
    render(<ClassView cohortId="c1" />)
    expect(
      screen.getByRole('heading', { level: 1, name: 'POS 2041-67' }),
    ).toBeInTheDocument()
    expect(screen.getByText('K7QX2M')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /copy code/i }))
    expect(writeText).toHaveBeenCalledWith('K7QX2M')
    expect(screen.getByRole('button', { name: /copied/i })).toBeInTheDocument()
  })

  it('one-pager requests the report by cohort_id and renders it in the new tab', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    const doc = {
      title: '',
      body: { textContent: '' },
      open: vi.fn(),
      write: vi.fn(),
      close: vi.fn(),
    }
    const open = vi
      .spyOn(window, 'open')
      .mockReturnValue({ document: doc, close: vi.fn() } as unknown as Window)
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response('<h1>summary</h1>', { status: 200 }))
    render(<ClassView cohortId="c1" />)
    await userEvent.click(
      screen.getByRole('button', { name: /summary one-pager/i }),
    )
    expect(open).toHaveBeenCalledWith('', '_blank')
    await waitFor(() => expect(doc.write).toHaveBeenCalled())
    expect(String(fetchMock.mock.calls[0][0])).toContain(
      '/functions/v1/efficacy-report?cohort_id=c1',
    )
    expect(doc.write).toHaveBeenCalledWith('<h1>summary</h1>')
    open.mockRestore()
    fetchMock.mockRestore()
  })

  it('one-pager explains when the class has no summary yet', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    const close = vi.fn()
    const open = vi.spyOn(window, 'open').mockReturnValue({
      document: { title: '', body: { textContent: '' } },
      close,
    } as unknown as Window)
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response('not found', { status: 404 }))
    render(<ClassView cohortId="c1" />)
    await userEvent.click(
      screen.getByRole('button', { name: /summary one-pager/i }),
    )
    expect(await screen.findByText(/no summary is available yet/i)).toBeInTheDocument()
    expect(close).toHaveBeenCalled()
    open.mockRestore()
    fetchMock.mockRestore()
  })

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

  it('keeps the live session draft when switching tabs and back', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    render(<ClassView cohortId="c1" />)
    await userEvent.click(screen.getByRole('tab', { name: /live/i }))
    await userEvent.click(screen.getByRole('button', { name: /set one up/i }))
    await userEvent.type(screen.getByLabelText(/session title/i), 'Friday review')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(screen.getByRole('tab', { name: /overview/i }))
    await userEvent.click(screen.getByRole('tab', { name: /live/i }))
    expect(screen.getByLabelText(/session title/i)).toHaveValue('Friday review')
    expect(screen.getByRole('checkbox', { name: /judiciary/i })).toBeChecked()
  })
})
