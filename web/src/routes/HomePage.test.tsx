import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type React from 'react'

const state = vi.hoisted(() => ({
  role: 'none' as string,
  request: null as null | { status: string },
  requestMutate: vi.fn(),
  joinClassMutate: vi.fn(),
}))

vi.mock('../lib/api', () => ({
  useMyConsoleRole: () => ({ data: state.role, isPending: false, error: null }),
  useMyAccessRequest: () => ({ data: state.request, isPending: false, error: null }),
  useRequestFacultyAccess: () => ({ mutate: state.requestMutate, isPending: false, error: null }),
  useMyStudentClasses: () => ({
    data: [{ cohort_id: 'c1', name: 'POS 2041-67', term: '2026F', professor: 'Purcell Demo', roster_name: 'Maria Lopez' }],
    isPending: false,
    error: null,
  }),
  useJoinClass: () => ({ mutate: state.joinClassMutate, isPending: false, error: null, isSuccess: false }),
  useMyClasses: () => ({ data: [], isPending: false, error: null }),
  useCreateCohort: () => ({ mutate: vi.fn(), isPending: false, error: null, data: undefined }),
  useFacultyRequests: () => ({ data: [], isPending: false, error: null }),
  useDecideFacultyRequest: () => ({ mutate: vi.fn(), isPending: false }),
  useMintFacultyInvite: () => ({ mutate: vi.fn(), isPending: false, data: undefined, error: null }),
  inviteLink: (c: string) => `link/${c}`,
}))

import { HomePage } from './HomePage'

const wrap = (ui: React.ReactElement) =>
  render(<QueryClientProvider client={new QueryClient()}>{ui}</QueryClientProvider>)

describe('HomePage', () => {
  beforeEach(() => {
    state.request = null
    state.requestMutate.mockClear()
  })

  it('offers request access to a signed-in user with no role', async () => {
    state.role = 'none'
    wrap(<HomePage />)
    await userEvent.type(screen.getByLabelText(/^school$/i), 'MDC North')
    await userEvent.type(screen.getByLabelText(/courses you teach/i), 'POS 2041')
    await userEvent.click(screen.getByRole('button', { name: /request access/i }))
    expect(state.requestMutate.mock.calls[0][0]).toEqual({
      school: 'MDC North',
      courses: 'POS 2041',
      note: '',
    })
  })

  it('shows the pending state once a request is open', () => {
    state.role = 'none'
    state.request = { status: 'pending' }
    wrap(<HomePage />)
    expect(screen.getByText(/request sent/i)).toBeInTheDocument()
  })

  it('gives students their classes, not the faculty console', () => {
    state.role = 'student'
    wrap(<HomePage />)
    expect(screen.getByText('POS 2041-67')).toBeInTheDocument()
    expect(screen.getByLabelText(/session code/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /create a class/i })).toBeNull()
  })

  it('gives faculty the classes console', () => {
    state.role = 'faculty'
    wrap(<HomePage />)
    expect(screen.getByRole('button', { name: /create a class/i })).toBeInTheDocument()
  })
})
