import { useEffect } from 'react'
import { Link, Outlet } from '@tanstack/react-router'
import { RequireAuth } from '../auth/RequireAuth'
import { useAmAdmin } from '../lib/api'
import { consoleOpen, useAdminHome } from './adminApi'
import { CommandPalette } from './CommandPalette'
import { A } from './strings'
import './admin.css'

const rail = [
  { to: '/admin', label: A.nav.home, glyph: '◉' },
  { to: '/admin/search', label: A.nav.search, glyph: '⌕' },
  { to: '/admin/invites', label: A.nav.invites, glyph: '✉' },
  { to: '/admin/audit', label: A.nav.audit, glyph: '▤' },
]

/** The console shell: admin check, header, rail, and the routed page. */
export function AdminLayoutInner() {
  const admin = useAmAdmin()
  const home = useAdminHome(admin.data === true)
  useEffect(() => {
    if (admin.data) void consoleOpen().catch(() => undefined)
  }, [admin.data])

  if (admin.isPending) return <div className="admin-root p-6">{A.loading}</div>
  if (!admin.data) {
    return (
      <div className="admin-root flex items-center justify-center p-6">
        <p>{A.notAvailable}</p>
      </div>
    )
  }
  const live = home.data?.live_now.length ?? 0
  return (
    <div className="admin-root flex flex-col">
      <header className="flex items-center gap-3 border-b border-[var(--a-line)] bg-[var(--a-panel)] px-3 py-2">
        <span className="admin-strong font-bold tracking-[0.12em]">{A.brand}</span>
        <CommandPalette />
        <span className={live > 0 ? 'sev-ok' : 'text-[var(--a-muted)]'}>● {A.live(live)}</span>
      </header>
      <div className="flex flex-1">
        <nav aria-label={A.nav.rail} className="flex w-12 flex-col items-center gap-3 border-r border-[var(--a-line)] pt-3">
          {rail.map(r => (
            <Link key={r.to} to={r.to as never} title={r.label} aria-label={r.label} className="text-[var(--a-muted)]">
              <span aria-hidden="true">{r.glyph}</span>
            </Link>
          ))}
        </nav>
        <main className="flex-1 p-3">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

// The route's actual lazy export: bundles its own auth gate, so the
// router preloads the real admin-only tree instead of a thin wrapper.
export function AdminLayout() {
  return (
    <RequireAuth>
      <AdminLayoutInner />
    </RequireAuth>
  )
}
