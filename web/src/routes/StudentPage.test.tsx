import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Drilldown } from '../lib/api'

const { sendMutate, assignMutate } = vi.hoisted(() => ({
  sendMutate: vi.fn(),
  assignMutate: vi.fn(),
}))

const drilldown: Drilldown = {
  identity: { student_ref: 'u1', display_name: 'Sam P' },
  domains: [
    { domain_id: 2, name: 'U.S. Constitution', readiness: 0.2, accuracy: 0.2 },
    { domain_id: 1, name: 'American Democracy', readiness: 0.7, accuracy: 0.72 },
  ],
  weak_objectives: [
    { objective_id: 'o1', code: '2.1', title: 'Articles of the Constitution', readiness: 0.15 },
  ],
  activity: {
    last_active: new Date().toISOString(),
    answers_7d: 5,
    answers_28d: 30,
    answers_total: 80,
    accuracy: 0.5,
  },
  live_sessions: [
    { session_id: 's1', title: 'Week 3 quiz', held_at: '2026-08-10T12:00:00Z', correct: 4, answered: 6 },
  ],
  mocks: { completed: 1, best_score: 44 },
  suggestions: ['Assign weak-area practice on U.S. Constitution (readiness 20%).'],
}

vi.mock('../lib/api', () => ({
  useDrilldown: () => ({ data: drilldown, isPending: false, error: null }),
  useSendAnnouncement: () => ({ mutate: sendMutate, isPending: false, isSuccess: false }),
  useLogExport: () => ({ mutate: vi.fn() }),
  useStudentTrend: () => ({
    data: {
      pass_line: 48,
      weeks: [
        { week_start: '2026-07-06', projected: 34, answers: 12, accuracy: 0.5 },
        { week_start: '2026-07-13', projected: 39, answers: 20, accuracy: 0.6 },
        { week_start: '2026-07-20', projected: 44, answers: 15, accuracy: 0.65 },
        { week_start: '2026-07-27', projected: 52, answers: 25, accuracy: 0.7 },
      ],
    },
    isPending: false,
    error: null,
  }),
  useAssignPractice: () => ({
    mutate: assignMutate,
    isPending: false,
    isSuccess: false,
    error: null,
  }),
}))
vi.mock('../lib/csv', () => ({ downloadCsv: vi.fn() }))

import { StudentView } from './StudentPage'

describe('StudentView', () => {
  it('renders the picture and prefills the class message from a suggestion', async () => {
    render(<StudentView cohortId="c1" studentRef="u1" />)
    expect(screen.getByRole('heading', { name: /Sam P/ })).toBeInTheDocument()
    const bars = screen.getAllByRole('img')
    expect(bars[0]).toHaveAccessibleName(/U.S. Constitution/)
    expect(screen.getByText(/Articles of the Constitution/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /message class/i }))
    const textarea = await screen.findByLabelText(/message/i, {
      selector: 'textarea',
    })
    expect(textarea).toHaveValue(
      'Assign weak-area practice on U.S. Constitution (readiness 20%).',
    )
    await userEvent.click(screen.getByRole('button', { name: /send to class/i }))
    expect(sendMutate).toHaveBeenCalledWith(
      expect.objectContaining({ cohortId: 'c1' }),
      expect.anything(),
    )
  })

  it('shows the weekly trend against the pass line', () => {
    render(<StudentView cohortId="c1" studentRef="u1" />)
    expect(screen.getByText(/projected score by week/i)).toBeInTheDocument()
    // sr table carries the weekly projections.
    expect(screen.getByRole('cell', { name: '52' })).toBeInTheDocument()
  })

  it('assigns weak-domain practice in one click', async () => {
    render(<StudentView cohortId="c1" studentRef="u1" />)
    // Only the weak domain (readiness 0.2) gets an assign button.
    const assign = screen.getByRole('button', {
      name: /assign u\.s\. constitution practice/i,
    })
    expect(
      screen.queryByRole('button', { name: /assign american democracy/i }),
    ).toBeNull()
    await userEvent.click(assign)
    expect(assignMutate).toHaveBeenCalledWith({ cohortId: 'c1', domainId: 2 })
  })
})
