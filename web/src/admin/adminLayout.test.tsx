import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const s = vi.hoisted(() => ({
  admin: true as boolean | undefined,
  healthy: true,
  navigate: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  useAmAdmin: () => ({ data: s.admin, isPending: s.admin === undefined }),
}))
vi.mock('../auth/RequireAuth', () => ({
  RequireAuth: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))
vi.mock('./adminApi', () => ({
  consoleOpen: vi.fn(async () => undefined),
  useAdminHome: () => ({
    data: { live_now: [{ session_id: 's1' }], health: { run_at: '2026-10-04T06:07:00Z', ok: s.healthy, failures: [] } },
  }),
  useAdminOnline: () => ({ data: { total: 14, ios: 11, web: 3, guests: 2, people: [] } }),
  hitPath: (h: { kind: string; id: string }) =>
    h.kind === 'person'
      ? `/admin/people/${h.id}`
      : h.kind === 'class'
        ? `/admin/classes/${h.id}`
        : `/admin/sessions/${h.id}`,
  useAdminSearch: (q: string) => ({
    data: q.length >= 2
      ? [{ kind: 'person', id: 'u1', title: 'Maria Lopez', subtitle: 'maria@students.example.edu' }]
      : [],
  }),
}))
vi.mock('@tanstack/react-router', () => ({
  Outlet: () => <p>page body</p>,
  Link: ({
    to,
    children,
    activeOptions: _activeOptions,
    ...rest
  }: {
    to: string
    children: React.ReactNode
    activeOptions?: unknown
  }) => (
    <a href={`#${to}`} {...rest}>{children}</a>
  ),
  useNavigate: () => s.navigate,
}))

import { AdminLayout } from './AdminLayout'

describe('AdminLayout', () => {
  it('admins get the console shell and the page', () => {
    s.admin = true
    render(<AdminLayout />)
    expect(screen.getByText('Politiface console')).toBeInTheDocument()
    expect(screen.getByText('page body')).toBeInTheDocument()
    expect(screen.getByText(/1 live now/)).toBeInTheDocument()
    expect(screen.getByText(/14 online \(iOS 11, web 3\)/)).toBeInTheDocument()
    expect(screen.getByText('System nominal')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Back to your classes' })).toHaveAttribute('href', '#/')
  })

  it('says so in words when the last system check failed', () => {
    s.admin = true
    s.healthy = false
    render(<AdminLayout />)
    expect(screen.getByText('System check failed')).toBeInTheDocument()
    expect(screen.queryByText('System nominal')).toBeNull()
    s.healthy = true
  })

  it('everyone else gets a notice, not the console', () => {
    s.admin = false
    render(<AdminLayout />)
    expect(screen.getByText(/not available/i)).toBeInTheDocument()
    expect(screen.queryByText('page body')).toBeNull()
  })

  it('Cmd-K opens an accessible modal; debounced search finds a hit; Enter opens it', async () => {
    s.admin = true
    render(<AdminLayout />)
    await userEvent.keyboard('{Meta>}k{/Meta}')
    const dialog = screen.getByRole('dialog')
    expect(dialog).toHaveAttribute('aria-modal', 'true')
    const input = screen.getByRole('searchbox')
    await userEvent.type(input, 'Maria')
    await waitFor(() => expect(screen.getByText('Maria Lopez')).toBeInTheDocument())
    await userEvent.keyboard('{Enter}')
    expect(s.navigate).toHaveBeenCalledWith({ to: '/admin/people/u1' })
  })

  it('Escape closes the palette and returns focus to the trigger button', async () => {
    s.admin = true
    render(<AdminLayout />)
    const trigger = screen.getByRole('button', { name: /Cmd-K/i })
    await userEvent.click(trigger)
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('dialog')).toBeNull()
    expect(trigger).toHaveFocus()
  })
})
