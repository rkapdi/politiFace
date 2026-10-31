import { describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const { logMutate, downloadCsvMock } = vi.hoisted(() => ({
  logMutate: vi.fn(),
  downloadCsvMock: vi.fn(),
}))

const atRiskRows = [
  {
    student_ref: 'u1',
    display_name: 'Sam P',
    overall_readiness: 0.35,
    weakest_domain_id: 2,
    weakest_domain_name: 'U.S. Constitution',
    weakest_readiness: 0.2,
    last_active: new Date(Date.now() - 3 * 86400_000).toISOString(),
    answers_14d: 4,
  },
]

const progressRows = [
  {
    user_id: 'u1',
    roster_name: 'Sam P',
    handle: 'sam_p',
    last_active: new Date().toISOString(),
    answers_total: 40,
    accuracy: 0.55,
    mocks_completed: 1,
    best_mock_score: 52,
    student_ref: 'u1',
  },
  {
    user_id: 'u2',
    roster_name: 'New Student',
    handle: 'new_student',
    last_active: null,
    answers_total: 0,
    accuracy: 0,
    mocks_completed: 0,
    best_mock_score: null,
    student_ref: 'u2',
  },
]

let atRiskError: Error | null = null
vi.mock('../lib/api', () => ({
  useAtRisk: () => ({
    data: atRiskError ? undefined : atRiskRows,
    isPending: false,
    error: atRiskError,
  }),
  useStudentProgress: () => ({
    data: atRiskError ? undefined : progressRows,
    isPending: false,
    error: atRiskError,
  }),
  useLogExport: () => ({ mutate: logMutate }),
}))
vi.mock('../lib/csv', () => ({ downloadCsv: downloadCsvMock }))

import { StudentsTab } from './StudentsTab'

describe('StudentsTab', () => {
  it('ranks every student by projected score and logs exports', async () => {
    render(<StudentsTab cohortId="c1" />)
    const links = screen.getAllByRole('link', { name: /Sam P/ })
    expect(links.length).toBe(1)
    expect(links[0]).toHaveAttribute('href', '#/class/c1/student/u1')
    // Coaching framing: a projected score out of 80, not a percentage.
    expect(screen.getByText('28 of 80')).toBeInTheDocument()
    expect(
      screen.getByText(/every student, lowest projected first/i),
    ).toBeInTheDocument()
    expect(screen.getByText(/U.S. Constitution/)).toBeInTheDocument()
    expect(screen.getByText(/3 days ago/)).toBeInTheDocument()
    await userEvent.click(
      screen.getByRole('button', { name: /export students csv/i }),
    )
    expect(logMutate).toHaveBeenCalledWith({ cohortId: 'c1', kind: 'csv_progress' })
    expect(downloadCsvMock).toHaveBeenCalled()
  })

  it('merges both reports into one row per student, including one only in progress', () => {
    render(<StudentsTab cohortId="c1" />)
    expect(screen.getAllByRole('table')).toHaveLength(1)
    const sam = screen.getByRole('row', { name: /Sam P/ })
    expect(within(sam).getByText('28 of 80')).toBeInTheDocument()
    expect(within(sam).getByText('55%')).toBeInTheDocument()
    expect(within(sam).getByText('52/80')).toBeInTheDocument()
    const newStudent = screen.getByRole('row', { name: /New Student/ })
    expect(within(newStudent).getByText('No data yet')).toBeInTheDocument()
    // Header plus exactly one row each.
    expect(screen.getAllByRole('row')).toHaveLength(3)
  })

  it('exports every student with both sets of columns, whatever the filter', async () => {
    downloadCsvMock.mockClear()
    render(<StudentsTab cohortId="c1" />)
    await userEvent.type(screen.getByRole('searchbox'), 'sam')
    await userEvent.click(screen.getByRole('button', { name: /export students csv/i }))
    const rows = downloadCsvMock.mock.calls[0][1]
    expect(rows).toHaveLength(2)
    expect(rows[0]).toMatchObject({ student: 'Sam P', readiness: 0.35, best_mock_score: 52 })
  })

  it('finds a student by name', async () => {
    render(<StudentsTab cohortId="c1" />)
    await userEvent.type(screen.getByRole('searchbox'), 'new')
    expect(screen.queryByRole('row', { name: /Sam P/ })).toBeNull()
    expect(screen.getByRole('row', { name: /New Student/ })).toBeInTheDocument()
    await userEvent.type(screen.getByRole('searchbox'), 'zzz')
    expect(screen.getByText(/no student matches/i)).toBeInTheDocument()
  })

  it('shows the aggregate-only explainer instead of tables', () => {
    atRiskError = new Error(
      'This class reports aggregate data only, so per-student views are off.',
    )
    render(<StudentsTab cohortId="c1" />)
    expect(screen.getByText(/aggregate data only/i)).toBeInTheDocument()
    expect(screen.queryByRole('table')).toBeNull()
    atRiskError = null
  })
})
