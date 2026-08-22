import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
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
  it('ranks at-risk students, links drill-down, and logs exports', async () => {
    render(<StudentsTab cohortId="c1" />)
    const links = screen.getAllByRole('link', { name: /Sam P/ })
    expect(links.length).toBe(2) // at-risk row and roster row
    expect(links[0]).toHaveAttribute('href', '#/class/c1/student/u1')
    expect(screen.getByText(/U.S. Constitution/)).toBeInTheDocument()
    expect(screen.getByText(/3 days ago/)).toBeInTheDocument()
    await userEvent.click(
      screen.getByRole('button', { name: /export at-risk csv/i }),
    )
    expect(logMutate).toHaveBeenCalledWith({ cohortId: 'c1', kind: 'csv_at_risk' })
    expect(downloadCsvMock).toHaveBeenCalled()
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
