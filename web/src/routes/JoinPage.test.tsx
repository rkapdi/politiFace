import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const joined = {
  id: 's1', title: 'Week 3 quiz', status: 'lobby', index: -1, total: 5, question_seconds: 20,
}
const m = vi.hoisted(() => ({
  session: null as null | { user: { id: string; is_anonymous: boolean } },
  preview: vi.fn(),
  joinMember: vi.fn(),
  joinStudent: vi.fn(),
  signInAnonymously: vi.fn(async () => ({})),
  joinGuest: vi.fn(),
  signOut: vi.fn(async () => undefined),
}))

vi.mock('../auth/SessionProvider', () => ({
  useSession: () => ({ session: m.session, loading: false, signOut: m.signOut }),
}))
vi.mock('../auth/EmailCodeForm', () => ({ EmailCodeForm: () => <p>email code form</p> }))
vi.mock('../lib/api', () => ({
  liveSessionPreview: m.preview,
  joinLiveSession: m.joinMember,
  joinLiveSessionAsStudent: m.joinStudent,
  signInAnonymously: m.signInAnonymously,
  joinLiveSessionGuest: m.joinGuest,
  submitLiveAnswer: vi.fn(),
  liveReveal: vi.fn(),
  liveScoreboard: vi.fn(async () => []),
}))
vi.mock('../lib/live', () => ({
  useLiveSession: () => ({ state: { status: 'lobby' }, error: null }),
}))

import { JoinPage } from './JoinPage'

const basePreview = {
  title: 'Week 3 quiz', status: 'lobby', allow_guests: false,
  class_name: 'POS 2041-67', professor: 'Purcell Demo',
  is_member: false, role: null, roster_name: null,
}
const wrap = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <JoinPage />
    </QueryClientProvider>,
  )

describe('JoinPage', () => {
  beforeEach(() => {
    window.location.hash = '#/join?code=abc123'
    m.session = null
    for (const f of [m.preview, m.joinMember, m.joinStudent, m.joinGuest]) f.mockReset()
    m.preview.mockResolvedValue(basePreview)
    m.joinMember.mockResolvedValue(joined)
    m.joinStudent.mockResolvedValue(joined)
    m.joinGuest.mockResolvedValue(joined)
  })

  it('signed out: shows the class and asks to sign in, no guest option by default', async () => {
    wrap()
    expect(await screen.findByText(/POS 2041-67/)).toBeInTheDocument()
    expect(screen.getByText(/Purcell Demo/)).toBeInTheDocument()
    expect(screen.getByText('email code form')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /without signing in/i })).toBeNull()
    expect(m.preview).toHaveBeenCalledWith('ABC123')
  })

  it('signed out, guests allowed: the guest path still works', async () => {
    m.preview.mockResolvedValue({ ...basePreview, allow_guests: true })
    wrap()
    await userEvent.click(await screen.findByRole('button', { name: /without signing in/i }))
    await userEvent.type(screen.getByLabelText(/your name/i), 'Alex R')
    await userEvent.click(screen.getByRole('button', { name: /^join$/i }))
    expect(m.signInAnonymously).toHaveBeenCalled()
    expect(m.joinGuest).toHaveBeenCalledWith('ABC123', 'Alex R')
    expect(await screen.findByText(/waiting for your instructor/i)).toBeInTheDocument()
  })

  it('signed in, first time: asks for the roster name and enrolls', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    wrap()
    await userEvent.type(await screen.findByLabelText(/as your professor knows it/i), 'Maria Lopez')
    await userEvent.click(screen.getByRole('button', { name: /join pos 2041-67/i }))
    expect(m.joinStudent).toHaveBeenCalledWith('ABC123', 'Maria Lopez')
    expect(await screen.findByText(/waiting for your instructor/i)).toBeInTheDocument()
  })

  it('signed in member: one tap', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.preview.mockResolvedValue({ ...basePreview, is_member: true, role: 'student', roster_name: 'Maria Lopez' })
    wrap()
    await userEvent.click(await screen.findByRole('button', { name: /join as maria lopez/i }))
    expect(m.joinMember).toHaveBeenCalledWith('ABC123')
  })

  it('signed in faculty of the class: sent back to the console', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    m.preview.mockResolvedValue({ ...basePreview, is_member: true, role: 'faculty' })
    wrap()
    expect(await screen.findByText(/you teach this class/i)).toBeInTheDocument()
  })

  it('not you: signs out', async () => {
    m.session = { user: { id: 'u1', is_anonymous: false } }
    wrap()
    await userEvent.click(await screen.findByRole('button', { name: /not you/i }))
    expect(m.signOut).toHaveBeenCalled()
  })

  it('no code in the link: asks for one', async () => {
    window.location.hash = '#/join'
    wrap()
    await userEvent.type(screen.getByLabelText(/session code/i), 'xyz789')
    await userEvent.click(screen.getByRole('button', { name: /continue/i }))
    expect(m.preview).toHaveBeenCalledWith('XYZ789')
  })
})
