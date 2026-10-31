import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'

const role = vi.hoisted(() => ({
  value: 'ta',
  send: vi.fn(),
  sent: undefined as number | null | undefined,
  sendError: null as null | Error,
}))

vi.mock('../lib/api', () => ({
  useOwnQuestions: () => ({ data: [], isPending: false, error: null }),
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
  useCohortRole: () => ({ data: role.value, isPending: false, error: null }),
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
        {
          kind: 'weak_domain',
          headline: 'U.S. Constitution is dragging the class',
          detail: 'Average readiness 46%.',
        },
        {
          kind: 'participation',
          headline: 'Only 12 of 32 practiced this week',
          detail: 'A class announcement brings students back.',
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
  useSendAnnouncement: () => ({
    mutate: role.send,
    isPending: false,
    isSuccess: role.sent !== undefined,
    data: role.sent === undefined ? undefined : { alerted: role.sent },
    error: role.sendError,
  }),
  useClassAnnouncements: (_c: string, enabled: boolean) => ({
    data: enabled
      ? [{ id: 'a1', body: 'Bring a laptop Thursday.', created_at: new Date().toISOString() }]
      : undefined,
    isPending: false,
    error: null,
  }),
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

import { ClassView, parseClassTab } from './ClassPage'

describe('ClassView messaging', () => {
  beforeEach(() => {
    role.value = 'faculty'
    role.send.mockReset()
    role.sent = undefined
    role.sendError = null
  })
  afterEach(() => {
    role.value = 'ta'
  })

  it('lets faculty message the class from the header and shows past messages', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    render(<ClassView cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /^message class$/i }))
    expect(await screen.findByText('Bring a laptop Thursday.')).toBeInTheDocument()
    const box = screen.getByLabelText(/^message$/i)
    expect(box).toHaveValue('')
    expect(box).toHaveAttribute('maxlength', '240')
    await userEvent.type(box, 'Mock on Friday')
    await userEvent.click(screen.getByRole('button', { name: /send to class/i }))
    expect(role.send.mock.calls[0][0]).toEqual({ cohortId: 'c1', body: 'Mock on Friday' })
  })

  it.each([
    [14, /14 devices alerted/i],
    [1, /1 device alerted/i],
    [0, /no student devices/i],
    [null, /phone alert did not go out/i],
  ])('reports what happened to the alert (%s)', async (alerted, expected) => {
    const { default: userEvent } = await import('@testing-library/user-event')
    role.sent = alerted
    render(<ClassView cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /^message class$/i }))
    expect(await screen.findByText(expected)).toBeInTheDocument()
  })

  it('shows a send failure instead of swallowing it', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    role.sendError = new Error('This class has reached 5 messages this hour. Try again shortly.')
    render(<ClassView cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /^message class$/i }))
    expect(await screen.findByRole('alert')).toHaveTextContent(/5 messages this hour/i)
  })

  it('gives TAs neither message path, since the server refuses them', () => {
    role.value = 'ta'
    render(<ClassView cohortId="c1" />)
    expect(screen.queryByRole('button', { name: /^message class$/i })).toBeNull()
    expect(screen.queryByRole('button', { name: /message the class/i })).toBeNull()
  })
})

describe('ClassView tabs and pulse', () => {
  it('follows the tab it is given and reports changes, so the URL can hold it', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    const onTabChange = vi.fn()
    render(<ClassView cohortId="c1" tab="students" onTabChange={onTabChange} />)
    expect(screen.getByRole('tab', { name: /students/i })).toHaveAttribute('aria-selected', 'true')
    await userEvent.click(screen.getByRole('tab', { name: /live/i }))
    expect(onTabChange).toHaveBeenCalledWith('live')
  })

  it('sends a TA who follows a settings link to the overview, not a blank panel', () => {
    render(<ClassView cohortId="c1" tab="settings" />)
    expect(screen.getByRole('tab', { name: /overview/i })).toHaveAttribute('aria-selected', 'true')
  })

  it('reads only known tabs from the URL', () => {
    expect(parseClassTab('students')).toBe('students')
    expect(parseClassTab('nonsense')).toBeUndefined()
    expect(parseClassTab(undefined)).toBeUndefined()
  })

  it('reteach opens a session already filtered to the weak domain', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    render(<ClassView cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /run a reteach session/i }))
    expect(screen.getByRole('tab', { name: /live/i })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByLabelText(/session title/i)).toBeInTheDocument()
    expect(screen.getByRole('combobox', { name: /^domain$/i })).toHaveValue('2')
  })
})

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
