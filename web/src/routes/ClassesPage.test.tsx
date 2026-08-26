import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import type { ClassOverviewRow } from '../lib/api'

const rows: ClassOverviewRow[] = [
  {
    cohort_id: 'c1',
    name: 'POS2041 Fall',
    term: '2026F',
    students: 32,
    active_7d: 21,
    answers_total: 480,
    accuracy: 0.71,
    mocks_completed: 12,
    live_sessions: 3,
  },
  {
    cohort_id: 'c2',
    name: 'Empty seminar',
    term: null as unknown as string,
    students: 0,
    active_7d: null as unknown as number,
    answers_total: null as unknown as number,
    accuracy: null as unknown as number,
    mocks_completed: null as unknown as number,
    live_sessions: 0,
  },
  {
    cohort_id: 'c3',
    name: 'Private seminar',
    term: null as unknown as string,
    students: 3,
    active_7d: null as unknown as number,
    answers_total: null as unknown as number,
    accuracy: null as unknown as number,
    mocks_completed: null as unknown as number,
    live_sessions: 0,
  },
]

vi.mock('../lib/api', () => ({
  useMyClasses: () => ({ data: rows, isPending: false, error: null }),
  useCreateCohort: () => ({
    mutate: vi.fn(),
    isPending: false,
    data: undefined,
    error: null,
  }),
}))

import { ClassesPage } from './ClassesPage'

describe('ClassesPage', () => {
  it('links each class and explains the below-floor state', () => {
    render(<ClassesPage />)
    const link = screen.getByRole('link', { name: /POS2041 Fall/ })
    expect(link).toHaveAttribute('href', '#/class/c1')
    expect(screen.getByText('32')).toBeInTheDocument()
    // 0 students: invite copy, not a floor message.
    expect(
      screen.getByText(/no students yet, share the class code/i),
    ).toBeInTheDocument()
    // Stats withheld with students present (aggregate-only small class).
    expect(screen.getByText(/stats withheld for privacy/i)).toBeInTheDocument()
  })
})
