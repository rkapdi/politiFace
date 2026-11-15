import { useEffect } from 'react'
import { Link, Outlet } from '@tanstack/react-router'
import { Activity, House, Mail, ScrollText, Search, type LucideIcon } from 'lucide-react'
import { RequireAuth } from '../auth/RequireAuth'
import { useAmAdmin } from '../lib/api'
import { BrandMark, ThemeToggle } from '../components/Brand'
import { consoleOpen, useAdminHome, useAdminOnline, type AdminHome } from './adminApi'
import { CommandPalette } from './CommandPalette'
import { A } from './strings'
import './admin.css'

const rail: { to: string; label: string; icon: LucideIcon; exact?: boolean }[] = [
  { to: '/admin', label: A.nav.home, icon: Activity, exact: true },
  { to: '/admin/search', label: A.nav.search, icon: Search },
  { to: '/admin/invites', label: A.nav.invites, icon: Mail },
  { to: '/admin/audit', label: A.nav.audit, icon: ScrollText },
]

// Every rail control is icon-only, so each carries its name as
// screen-reader text and as a hover title.
const item =
  'flex size-10 shrink-0 items-center justify-center rounded-md text-ink-2 no-underline transition-colors hover:bg-control hover:text-ink [&.active]:bg-nav [&.active]:text-on-nav'

const pill =
  'flex h-11 shrink-0 items-center gap-2 rounded-full bg-panel px-4 text-[13px] font-semibold'

/** A filled dot means on, a hollow one means off: never colour alone. */
function Dot({ on, risk = false }: { on: boolean; risk?: boolean }) {
  return (
    <span
      aria-hidden="true"
      className={`size-2 shrink-0 rounded-full ${
        risk ? 'ring-[1.5px] ring-inset ring-risk' : on ? 'bg-accent' : 'ring-[1.5px] ring-inset ring-ink-3'
      }`}
    />
  )
}

function Health({ health }: { health: AdminHome['health'] | undefined }) {
  if (health === undefined) return null
  const ok = health?.ok === true
  const label =
    health == null ? A.home.healthUnknown : ok ? A.home.healthNominal : A.home.healthCheck
  return (
    <span className={`${pill} ${ok ? 'text-ink' : health == null ? 'text-ink-3' : 'text-risk ring-[1.5px] ring-inset ring-risk-line'}`}>
      <Dot on={ok} risk={health != null && !ok} />
      {label}
    </span>
  )
}

/** The console shell: admin check, rail, status bar, and the routed page. */
export function AdminLayoutInner() {
  const admin = useAmAdmin()
  const home = useAdminHome(admin.data === true)
  const online = useAdminOnline(admin.data === true)
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
  const on = online.data
  return (
    <div className="admin-root flex flex-col gap-3 p-3 sm:flex-row sm:items-start">
      <header className="z-30 flex shrink-0 items-center justify-between gap-2 rounded-xl bg-panel px-3 py-2 sm:sticky sm:top-3 sm:h-[calc(100vh-1.5rem)] sm:w-16 sm:flex-col sm:px-0 sm:py-3.5">
        <div className="flex items-center gap-1.5 sm:flex-col">
          <span className="mr-2 sm:mb-3 sm:mr-0">
            <BrandMark />
            <span className="sr-only">{A.brand}</span>
          </span>
          <nav aria-label={A.nav.rail} className="flex items-center gap-1.5 sm:flex-col">
            {rail.map(r => (
              <Link
                key={r.to}
                to={r.to as never}
                title={r.label}
                className={item}
                activeOptions={{ exact: r.exact === true }}
              >
                <r.icon aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
                <span className="sr-only">{r.label}</span>
              </Link>
            ))}
          </nav>
        </div>
        <div className="flex items-center gap-1.5 sm:flex-col">
          <ThemeToggle className={item} />
          <Link to="/" title={A.nav.backToClasses} className={item}>
            <House aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
            <span className="sr-only">{A.nav.backToClasses}</span>
          </Link>
        </div>
      </header>
      <div className="flex min-w-0 flex-1 flex-col gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <CommandPalette />
          {on ? (
            <span className={`${pill} ${on.total > 0 ? 'text-ink' : 'text-ink-3'}`}>
              <Dot on={on.total > 0} />
              {A.online(on.total, on.ios, on.web)}
            </span>
          ) : null}
          <span className={`${pill} ${live > 0 ? 'text-ink' : 'text-ink-3'}`}>
            <Dot on={live > 0} />
            {A.live(live)}
          </span>
          <Health health={home.data ? home.data.health : undefined} />
        </div>
        <main className="min-w-0 pb-10">
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
