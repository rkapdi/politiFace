import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type React from 'react'
import { S } from '../lib/strings'

const state = vi.hoisted(() => ({
  role: 'none' as string,
  request: null as null | { status: string },
  requestMutate: vi.fn(),
  joinClassMutate: vi.fn(),
  preview: vi.fn(),
}))

vi.mock('../lib/api', () => ({
  liveSessionPreview: state.preview,
  useMyConsoleRole: () => ({ data: state.role, isPending: false, error: null }),
  useMyAccessRequest: () => ({ data: state.request, isPending: false, error: null }),
  useRequestFacultyAccess: () => ({ mutate: state.requestMutate, isPending: false, error: null }),
  useMyStudentClasses: () => ({
    data: [{ cohort_id: 'c1', name: 'POS 2041-67', term: '2026F', professor: 'Rivera Demo', roster_name: 'Maria Lopez' }],
    isPending: false,
    error: null,
  }),
  useJoinClass: () => ({ mutate: state.joinClassMutate, reset: vi.fn(), isPending: false, error: null, isSuccess: false }),
  useMyClasses: () => ({ data: [], isPending: false, error: null }),
  useCreateCohort: () => ({ mutate: vi.fn(), isPending: false, error: null, data: undefined }),
  useAmVerifiedFaculty: () => ({ data: true, isPending: false, error: null }),
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
    state.joinClassMutate.mockClear()
    state.preview.mockReset()
  })

  it('one code box: a class code asks for the roster name, then joins', async () => {
    state.role = 'none'
    state.preview.mockRejectedValue(new Error(S.errors.badSessionCode))
    wrap(<HomePage />)
    await userEvent.type(screen.getByLabelText(/class or session code/i), 'k7qx2m')
    await userEvent.click(screen.getByRole('button', { name: /^continue$/i }))
    // Prefilled from how another class already lists this student.
    const name = await screen.findByLabelText(/as your professor knows it/i)
    expect(name).toHaveValue('Maria Lopez')
    expect(state.preview).toHaveBeenCalledWith('K7QX2M')
    await userEvent.click(screen.getByRole('button', { name: /^join class$/i }))
    expect(state.joinClassMutate.mock.calls[0][0]).toEqual({
      code: 'K7QX2M',
      rosterName: 'Maria Lopez',
    })
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1)
  })

  it('one code box: a running session goes straight to the join page', async () => {
    state.role = 'student'
    state.preview.mockResolvedValue({ title: 'Week 3 quiz' })
    wrap(<HomePage />)
    await userEvent.type(screen.getByLabelText(/class or session code/i), 'abc123')
    await userEvent.click(screen.getByRole('button', { name: /^continue$/i }))
    await waitFor(() => expect(window.location.hash).toBe('#/join?code=ABC123'))
    expect(state.joinClassMutate).not.toHaveBeenCalled()
  })

  it('one code box: a network failure is not mistaken for a class code', async () => {
    state.role = 'student'
    state.preview.mockRejectedValue(new Error(S.errors.offline))
    wrap(<HomePage />)
    await userEvent.type(screen.getByLabelText(/class or session code/i), 'abc123')
    await userEvent.click(screen.getByRole('button', { name: /^continue$/i }))
    expect(await screen.findByText(S.errors.offline)).toBeInTheDocument()
    expect(screen.queryByLabelText(/as your professor knows it/i)).toBeNull()
  })

  it('keeps instructor access one tap away instead of showing students the form', async () => {
    state.role = 'none'
    wrap(<HomePage />)
    expect(screen.queryByLabelText(/^school$/i)).toBeNull()
    await userEvent.click(screen.getByRole('button', { name: S.requestAccess.open }))
    await userEvent.type(screen.getByLabelText(/invite code/i), 'd7qmja')
    await userEvent.click(screen.getByRole('button', { name: S.requestAccess.useInvite }))
    expect(window.location.hash).toBe('#/welcome?invite=D7QMJA')
  })

  it('offers request access to a signed-in user with no role', async () => {
    state.role = 'none'
    wrap(<HomePage />)
    await userEvent.click(screen.getByRole('button', { name: S.requestAccess.open }))
    await userEvent.type(screen.getByLabelText(/^school$/i), 'Example College')
    await userEvent.type(screen.getByLabelText(/courses you teach/i), 'POS 2041')
    await userEvent.click(screen.getByRole('button', { name: /request access/i }))
    expect(state.requestMutate.mock.calls[0][0]).toEqual({
      school: 'Example College',
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
    expect(screen.getByLabelText(/class or session code/i)).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: /create a class/i })).toBeNull()
  })

  it('gives faculty the classes console', () => {
    state.role = 'faculty'
    wrap(<HomePage />)
    // No classes yet: the form is already open, one step from the first class.
    expect(screen.getByRole('heading', { name: /create a class/i })).toBeInTheDocument()
    expect(screen.getByLabelText(/class name/i)).toBeInTheDocument()
  })
})
