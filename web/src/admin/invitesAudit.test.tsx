import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'

const m = vi.hoisted(() => ({
  mint: vi.fn((_a: unknown, o?: { onSuccess?: (c: string) => void }) => o?.onSuccess?.('D7QMJA')),
  revoke: vi.fn(),
}))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, params, children }: { to: string; params?: Record<string, string>; children: React.ReactNode }) => (
    <a href={`#${Object.entries(params ?? {}).reduce((p, [k, v]) => p.replace(`$${k}`, v), to)}`}>{children}</a>
  ),
}))
vi.mock('../lib/api', () => ({ inviteLink: (c: string) => `https://politiface.app/app/#/welcome?invite=${c}` }))
vi.mock('./adminApi', () => ({
  useAdminInvites: () => ({
    data: [
      { code: 'AAAAAA', note: 'For Prof. X', minted_by_handle: 'DawoodShah', recipient_email: 'x@mdc.edu', uses: 0, max_uses: 1, created_at: '2026-10-01T00:00:00Z', expires_at: '2026-10-15T00:00:00Z', revoked_at: null, status: 'active' },
      { code: 'BBBBBB', note: null, minted_by_handle: 'DawoodShah', recipient_email: null, uses: 1, max_uses: 1, created_at: '2026-09-20T00:00:00Z', expires_at: '2026-10-04T00:00:00Z', revoked_at: null, status: 'used' },
    ],
    isPending: false,
    error: null,
  }),
  useMintInvite: () => ({ mutate: m.mint, isPending: false, error: null }),
  useRevokeInvite: () => ({ mutate: m.revoke, isPending: false, error: null }),
  useAdminAudit: () => ({
    data: [{ id: 1, created_at: '2026-10-04T12:00:00Z', actor_handle: 'bright_quill_1321', action: 'faculty_granted', target_user: 'u1', target_label: 'Purcell Demo', target_cohort: null, target_session: null, details: {} }],
    isPending: false,
    error: null,
  }),
}))

import { InvitesPage } from './InvitesPage'
import { AuditPage } from './AuditPage'

describe('InvitesPage', () => {
  it('lists invites with status, mints a link, revokes only active ones', async () => {
    render(<InvitesPage />)
    expect(screen.getByText('AAAAAA')).toBeInTheDocument()
    expect(screen.getByText('active')).toBeInTheDocument()
    expect(screen.getByText('used')).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: /revoke/i })).toHaveLength(1)
    await userEvent.click(screen.getByRole('button', { name: /revoke/i }))
    expect(m.revoke).toHaveBeenCalledWith('AAAAAA')
    await userEvent.type(screen.getByLabelText(/their email/i), 'new@mdc.edu')
    await userEvent.click(screen.getByRole('button', { name: /create invite link/i }))
    expect(m.mint.mock.calls[0][0]).toEqual({ recipientEmail: 'new@mdc.edu', note: '' })
    expect(screen.getByDisplayValue(/invite=D7QMJA/)).toBeInTheDocument()
  })

  it('has no axe violations', async () => {
    const { container } = render(<div className="admin-root"><InvitesPage /></div>)
    const results = await axe(container)
    expect(results.violations).toEqual([])
  })
})

describe('AuditPage', () => {
  it('lists admin actions with actor and target', () => {
    render(<AuditPage />)
    expect(screen.getByText('bright_quill_1321')).toBeInTheDocument()
    expect(screen.getByText('faculty granted')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Purcell Demo' })).toHaveAttribute('href', '#/admin/people/u1')
  })
})
