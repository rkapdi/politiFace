import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'

const m = vi.hoisted(() => ({
  mint: vi.fn((_a: unknown, o?: { onSuccess?: (c: string) => void }) => o?.onSuccess?.('D7QMJA')),
  revoke: vi.fn(),
  auditArg: undefined as string | undefined,
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
  useAdminAudit: (action?: string) => {
    m.auditArg = action
    return {
      data: [
        { id: 1, created_at: '2026-10-04T12:00:00Z', actor_handle: 'bright_quill_1321', action: 'faculty_granted', target_user: 'u1', target_label: 'Purcell Demo', target_cohort: null, target_session: null, details: {} },
        { id: 2, created_at: '2026-10-04T12:05:00Z', actor_handle: 'DawoodShah', action: 'invite_revoked', target_user: null, target_label: null, target_cohort: null, target_session: null, details: { code: 'D7QMJA' } },
      ],
      isPending: false,
      error: null,
    }
  },
}))

import { InvitesPage } from './InvitesPage'
import { AuditPage } from './AuditPage'

describe('InvitesPage', () => {
  it('lists invites with status, mints a link, revokes only active ones', async () => {
    render(<InvitesPage />)
    expect(screen.getByText('AAAAAA')).toBeInTheDocument()
    expect(screen.getByText('active')).toBeInTheDocument()
    expect(screen.getByText('used')).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: /^revoke$/i })).toHaveLength(1)
    const revokeButton = screen.getByRole('button', { name: /^revoke$/i })
    await userEvent.click(revokeButton)
    expect(screen.getByRole('group', { name: /confirm invite revocation/i })).toBeInTheDocument()
    expect(m.revoke).not.toHaveBeenCalled()
    const confirmButton = screen.getByRole('button', { name: /^confirm$/i })
    expect(confirmButton).toHaveFocus()
    await userEvent.click(confirmButton)
    expect(m.revoke).toHaveBeenCalledWith('AAAAAA')
    expect(screen.getByRole('button', { name: /^revoke$/i })).toHaveFocus()
    await userEvent.type(screen.getByLabelText(/their email/i), 'new@mdc.edu')
    await userEvent.click(screen.getByRole('button', { name: /create invite link/i }))
    expect(m.mint.mock.calls[0][0]).toEqual({ recipientEmail: 'new@mdc.edu', note: '' })
    expect(screen.getByDisplayValue(/invite=D7QMJA/)).toBeInTheDocument()

    const writeText = vi.fn(async () => undefined)
    Object.assign(navigator, { clipboard: { writeText } })
    await userEvent.click(screen.getByRole('button', { name: /^copy$/i }))
    expect(writeText).toHaveBeenCalledWith(expect.stringContaining('invite=D7QMJA'))
    expect(await screen.findByRole('button', { name: /^copied$/i })).toBeInTheDocument()
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
    expect(screen.getByRole('cell', { name: 'bright_quill_1321' })).toBeInTheDocument()
    expect(screen.getByRole('cell', { name: 'faculty granted' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Purcell Demo' })).toHaveAttribute('href', '#/admin/people/u1')
    expect(screen.getByText(/code: D7QMJA/)).toBeInTheDocument()
  })

  it('filters by action, passing it through to the query', async () => {
    render(<AuditPage />)
    expect(m.auditArg).toBeUndefined()
    await userEvent.selectOptions(screen.getByLabelText(/^action$/i), 'faculty_granted')
    expect(m.auditArg).toBe('faculty_granted')
  })

  it('filters by actor, client-side, from the distinct actors in the loaded rows', async () => {
    render(<AuditPage />)
    expect(screen.getByRole('cell', { name: 'bright_quill_1321' })).toBeInTheDocument()
    expect(screen.getByRole('cell', { name: 'DawoodShah' })).toBeInTheDocument()
    await userEvent.selectOptions(screen.getByLabelText(/actor/i), 'DawoodShah')
    expect(screen.queryByRole('cell', { name: 'bright_quill_1321' })).toBeNull()
    expect(screen.getByRole('cell', { name: 'DawoodShah' })).toBeInTheDocument()
    // Purely client-side: the action query is untouched by the actor filter.
    expect(m.auditArg).toBeUndefined()
  })
})
