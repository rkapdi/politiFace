import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const m = vi.hoisted(() => ({
  session: null as null | { user: { id: string; is_anonymous: boolean } },
  loading: false,
  preview: vi.fn(
    async (): Promise<{ valid: boolean; inviter: string | null }> => ({
      valid: true,
      inviter: 'AdminTwo',
    }),
  ),
  role: vi.fn(async () => 'none'),
  classes: vi.fn(async (): Promise<unknown[]> => []),
  profile: { handle: 'user_1234abcd', school: null as string | null },
  redeem: vi.fn(async () => undefined),
  updateProfile: vi.fn((_a: unknown, o?: { onSuccess?: () => void }) => o?.onSuccess?.()),
  createCohort: vi.fn((_a: unknown, o?: { onSuccess?: (d: { id: string; join_code: string }) => void }) =>
    o?.onSuccess?.({ id: 'c9', join_code: 'ABC123' })),
}))

vi.mock('../auth/SessionProvider', () => ({
  useSession: () => ({ session: m.session, loading: m.loading, signOut: vi.fn() }),
}))
vi.mock('../auth/EmailCodeForm', () => ({ EmailCodeForm: () => <p>email code form</p> }))
vi.mock('../lib/api', () => ({
  invitePreview: m.preview,
  myClasses: m.classes,
  myConsoleRole: m.role,
  redeemFacultyInvite: m.redeem,
  useUpdateMyProfile: () => ({ mutate: m.updateProfile, isPending: false, error: null }),
  useCreateCohort: () => ({ mutate: m.createCohort, isPending: false, error: null }),
  useMyProfile: () => ({ data: m.profile }),
}))

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WelcomePage } from './WelcomePage'

const wrap = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <WelcomePage />
    </QueryClientProvider>,
  )

describe('WelcomePage', () => {
  beforeEach(() => {
    window.location.hash = '#/welcome?invite=d7qmja'
    m.session = null
    m.loading = false
    m.redeem.mockClear()
    m.createCohort.mockClear()
    m.profile = { handle: 'user_1234abcd', school: null }
  })

  it('session still loading: shows a spinner, no email form yet', () => {
    m.loading = true
    wrap()
    expect(screen.getByRole('heading', { name: /invited to politiface/i })).toBeInTheDocument()
    expect(screen.getByText(/checking your session/i)).toBeInTheDocument()
    expect(screen.queryByText('email code form')).toBeNull()
  })

  it('signed out: shows the inviter and the email-code form', async () => {
    wrap()
    expect(await screen.findByText(/AdminTwo/)).toBeInTheDocument()
    expect(screen.getByText('email code form')).toBeInTheDocument()
    expect(m.preview).toHaveBeenCalledWith('D7QMJA')
  })

  it('expired link: says so and offers no sign-in', async () => {
    m.preview.mockResolvedValueOnce({ valid: false, inviter: null })
    wrap()
    expect(await screen.findByText(/expired or was already used/i)).toBeInTheDocument()
    expect(screen.queryByText('email code form')).toBeNull()
  })

  it('signed in: redeems once, then profile, then first class, then opens it', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    wrap()
    await waitFor(() => expect(m.redeem).toHaveBeenCalledWith('D7QMJA'))
    const name = await screen.findByLabelText(/display name/i)
    expect(name).toHaveValue('')
    await userEvent.type(name, 'Rivera Demo')
    await userEvent.type(screen.getByLabelText(/^school$/i), 'Example College')
    await userEvent.click(screen.getByRole('button', { name: /next/i }))
    await userEvent.type(await screen.findByLabelText(/class name/i), 'POS 2041-67')
    await userEvent.type(screen.getByLabelText(/term/i), '2026F')
    await userEvent.click(screen.getByRole('button', { name: /create class/i }))
    expect(m.createCohort.mock.calls[0][0]).toEqual({ name: 'POS 2041-67', term: '2026F' })
    expect(window.location.hash).toBe('#/class/c9')
    expect(m.redeem).toHaveBeenCalledTimes(1)
  })

  it('already an instructor: skips redeeming', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.role.mockResolvedValueOnce('faculty')
    wrap()
    expect(await screen.findByLabelText(/display name/i)).toBeInTheDocument()
    expect(m.redeem).not.toHaveBeenCalled()
  })

  it('reopening an old invite with classes already: straight to the classes', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.role.mockResolvedValueOnce('faculty')
    m.classes.mockResolvedValueOnce([{ cohort_id: 'c1' }])
    wrap()
    await waitFor(() => expect(window.location.hash).toBe('#/'))
    expect(screen.queryByLabelText(/display name/i)).toBeNull()
  })

  it('profile already filled in: skips to the first class', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.profile = { handle: 'Rivera Demo', school: 'Example College' }
    wrap()
    expect(await screen.findByLabelText(/class name/i)).toBeInTheDocument()
    expect(screen.queryByLabelText(/display name/i)).toBeNull()
  })

  it('a refused invite offers a way out, not a dead end', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.redeem.mockRejectedValueOnce(new Error('That invite link has expired'))
    wrap()
    expect(await screen.findByText(/invite link has expired/i)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /go to your classes/i })).toHaveAttribute('href', '#/')
  })
})
