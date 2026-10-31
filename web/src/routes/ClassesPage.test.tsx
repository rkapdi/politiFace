import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { S } from '../lib/strings'
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

const state = vi.hoisted(() => ({
  createError: null as null | { message: string },
  createMutate: vi.fn(),
  role: 'faculty',
}))

vi.mock('../lib/api', () => ({
  useMyClasses: () => ({ data: rows, isPending: false, error: null }),
  useCreateCohort: () => ({
    mutate: state.createMutate,
    isPending: false,
    data: undefined,
    error: state.createError,
  }),
  useMyConsoleRole: () => ({ data: state.role }),
  useAmVerifiedFaculty: () => ({ data: true, isPending: false, error: null }),
  useMintFacultyInvite: () => ({ mutate: vi.fn(), isPending: false, error: null }),
  inviteLink: (c: string) => c,
  useMyAccessRequest: () => ({ data: null, isPending: false, error: null }),
  useRequestFacultyAccess: () => ({ mutate: vi.fn(), isPending: false, error: null }),
}))

import { ClassesPage } from './ClassesPage'

describe('ClassesPage', () => {
  beforeEach(() => {
    state.createError = null
    state.role = 'faculty'
    state.createMutate.mockReset()
  })

  it('a new class opens on its own page, where the join code already is', async () => {
    state.createMutate.mockImplementation((_a, o) => o?.onSuccess?.({ id: 'c9', join_code: 'ABC123' }))
    render(<ClassesPage />)
    await userEvent.click(screen.getByRole('button', { name: /create a class/i }))
    await userEvent.type(screen.getByLabelText(/class name/i), 'Section A')
    await userEvent.click(screen.getByRole('button', { name: /^create$/i }))
    expect(window.location.hash).toBe('#/class/c9')
  })

  it('offers verified instructors a colleague invite, behind one tap; staff use the console', async () => {
    const { unmount } = render(<ClassesPage />)
    expect(screen.queryByLabelText(/their email/i)).toBeNull()
    await userEvent.click(screen.getByRole('button', { name: /invite a colleague/i }))
    expect(screen.getByLabelText(/their email/i)).toBeInTheDocument()
    unmount()
    state.role = 'staff'
    render(<ClassesPage />)
    expect(screen.queryByRole('button', { name: /invite a colleague/i })).toBeNull()
  })

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

  it('a TA or unverified co-faculty blocked from creating a class gets a way to ask, right there', async () => {
    state.createError = { message: S.errors.needsVerification }
    render(
      <QueryClientProvider client={new QueryClient()}>
        <ClassesPage />
      </QueryClientProvider>,
    )
    await userEvent.click(screen.getAllByRole('button', { name: /create a class/i })[0])
    expect(screen.getByText(S.errors.needsVerification)).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: S.requestAccess.title })).toBeInTheDocument()
  })

  it('guides professors toward neutral class names', async () => {
    state.createError = null
    render(
      <QueryClientProvider client={new QueryClient()}>
        <ClassesPage />
      </QueryClientProvider>,
    )
    await userEvent.click(screen.getAllByRole('button', { name: /create a class/i })[0])
    expect(screen.getByPlaceholderText('Section A')).toBeInTheDocument()
    expect(screen.getByText(/course codes, section and CRN numbers/i)).toBeInTheDocument()
  })
})
