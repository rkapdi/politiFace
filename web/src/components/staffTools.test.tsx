import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const s = vi.hoisted(() => ({
  role: 'staff',
  verifiedFaculty: true,
  mint: vi.fn((_a: unknown, o?: { onSuccess?: (c: string) => void }) => o?.onSuccess?.('D7QMJA')),
  decide: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  useMyConsoleRole: () => ({ data: s.role }),
  useAmVerifiedFaculty: () => ({ data: s.verifiedFaculty, isPending: false, error: null }),
  useMintFacultyInvite: () => ({ mutate: s.mint, isPending: false, error: null }),
  inviteLink: (c: string) => `https://politiface.app/app/#/welcome?invite=${c}`,
  useFacultyRequests: (enabled: boolean) => ({
    data: enabled
      ? [{ id: 'r1', user_id: 'u1', handle: 'jmalagon', email: 'jm@mdc.edu', school: 'MDC North', courses: 'POS 2041', note: null, created_at: '2026-09-28T12:00:00Z' }]
      : undefined,
    isPending: false,
    error: null,
  }),
  useDecideFacultyRequest: () => ({ mutate: s.decide, isPending: false }),
}))

import { StaffTools } from './StaffTools'

describe('StaffTools', () => {
  it('mints an invite and shows the welcome link', async () => {
    render(<StaffTools />)
    await userEvent.type(screen.getByLabelText(/their email/i), 'new@mdc.edu')
    await userEvent.click(screen.getByRole('button', { name: /create invite link/i }))
    expect(s.mint.mock.calls[0][0]).toEqual({ recipientEmail: 'new@mdc.edu', note: '' })
    expect(screen.getByDisplayValue(/#\/welcome\?invite=D7QMJA/)).toBeInTheDocument()
  })

  it('staff approve a pending request', async () => {
    render(<StaffTools />)
    expect(screen.getByText(/jm@mdc\.edu/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /approve/i }))
    expect(s.decide.mock.calls[0][0]).toEqual({ id: 'r1', approve: true })
  })

  it('faculty get invites but not the request queue', () => {
    s.role = 'faculty'
    s.verifiedFaculty = true
    render(<StaffTools />)
    expect(screen.getByRole('button', { name: /create invite link/i })).toBeInTheDocument()
    expect(screen.queryByText(/instructor requests/i)).toBeNull()
  })

  it('unverified co-faculty see no invite card (they would hit an unmapped mint error)', () => {
    s.role = 'faculty'
    s.verifiedFaculty = false
    render(<StaffTools />)
    expect(screen.queryByRole('button', { name: /create invite link/i })).toBeNull()
  })
})
