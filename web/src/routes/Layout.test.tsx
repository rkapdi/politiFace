import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'

const s = vi.hoisted(() => ({ admin: false as boolean }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, children }: { to: string; children: React.ReactNode }) => (
    <a href={`#${to}`}>{children}</a>
  ),
  Outlet: () => null,
}))
vi.mock('../auth/SessionProvider', () => ({
  useSession: () => ({
    session: { user: { id: 'u1', is_anonymous: false } },
    loading: false,
    signOut: vi.fn(),
  }),
}))
vi.mock('../lib/api', () => ({
  useAmAdmin: () => ({ data: s.admin }),
  useMyProfile: () => ({ data: { handle: 'founder_1' }, isPending: false, error: null }),
}))

import { Layout } from './Layout'

describe('Layout header Console link', () => {
  it('is hidden for non-admins', () => {
    s.admin = false
    render(<Layout />)
    expect(screen.queryByRole('link', { name: 'Console' })).toBeNull()
  })

  it('is shown for admins and points at /admin', () => {
    s.admin = true
    render(<Layout />)
    expect(screen.getByRole('link', { name: 'Console' })).toHaveAttribute('href', '#/admin')
  })
})
