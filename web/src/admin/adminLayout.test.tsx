import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const s = vi.hoisted(() => ({ admin: true as boolean | undefined, navigate: vi.fn() }))
vi.mock('../lib/api', () => ({
  useAmAdmin: () => ({ data: s.admin, isPending: s.admin === undefined }),
}))
vi.mock('./adminApi', () => ({
  consoleOpen: vi.fn(async () => undefined),
  useAdminHome: () => ({ data: { live_now: [{ session_id: 's1' }] } }),
  useAdminSearch: (q: string) => ({
    data: q.length >= 2
      ? [{ kind: 'person', id: 'u1', title: 'Maria Lopez', subtitle: 'maria@mymdc.net' }]
      : [],
  }),
}))
vi.mock('@tanstack/react-router', () => ({
  Outlet: () => <p>page body</p>,
  Link: ({ to, children, ...rest }: { to: string; children: React.ReactNode }) => (
    <a href={`#${to}`} {...rest}>{children}</a>
  ),
  useNavigate: () => s.navigate,
}))

import { AdminLayout } from './AdminLayout'

describe('AdminLayout', () => {
  it('admins get the console shell and the page', () => {
    s.admin = true
    render(<AdminLayout />)
    expect(screen.getByText('POLITIFACE // CONSOLE')).toBeInTheDocument()
    expect(screen.getByText('page body')).toBeInTheDocument()
    expect(screen.getByText(/LIVE 1/)).toBeInTheDocument()
  })

  it('everyone else gets a notice, not the console', () => {
    s.admin = false
    render(<AdminLayout />)
    expect(screen.getByText(/not available/i)).toBeInTheDocument()
    expect(screen.queryByText('page body')).toBeNull()
  })

  it('Cmd-K opens search and Enter opens the first hit', async () => {
    s.admin = true
    render(<AdminLayout />)
    await userEvent.keyboard('{Meta>}k{/Meta}')
    await userEvent.type(screen.getByRole('combobox'), 'Maria')
    expect(screen.getByText('Maria Lopez')).toBeInTheDocument()
    await userEvent.keyboard('{Enter}')
    expect(s.navigate).toHaveBeenCalledWith({ to: '/admin/people/u1' })
  })
})
