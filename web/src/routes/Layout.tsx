import { Link, Outlet } from '@tanstack/react-router'
import { House, LogOut, Terminal, User } from 'lucide-react'
import { RequireAuth } from '../auth/RequireAuth'
import { useSession } from '../auth/SessionProvider'
import { useAmAdmin, useMyProfile } from '../lib/api'
import { S } from '../lib/strings'
import { BrandMark, ThemeToggle } from '../components/Brand'

// Every rail control is icon-only, so each carries its name as
// screen-reader text and as a hover title.
const item =
  'flex size-10 shrink-0 items-center justify-center rounded-md text-ink-2 transition-colors hover:bg-control hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus [&.active]:bg-nav [&.active]:text-on-nav'

function Rail() {
  const { session, signOut } = useSession()
  const profile = useMyProfile(session?.user.id ?? '')
  const isAdmin = useAmAdmin().data === true
  const account = profile.data?.handle ?? S.account.title
  return (
    <header className="z-30 flex shrink-0 items-center justify-between gap-2 rounded-xl bg-panel px-3 py-2 sm:sticky sm:top-3 sm:h-[calc(100vh-1.5rem)] sm:w-16 sm:flex-col sm:px-0 sm:py-3.5 print:hidden">
      <div className="flex items-center gap-1.5 sm:flex-col">
        <span className="mr-2 sm:mb-3 sm:mr-0">
          <BrandMark />
          <span className="sr-only">Politiface</span>
        </span>
        <nav aria-label="Main" className="flex items-center gap-1.5 sm:flex-col">
          <Link to="/" className={item} title={S.student.title} activeOptions={{ exact: true }}>
            <House aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
            <span className="sr-only">{S.student.title}</span>
          </Link>
          {isAdmin ? (
            <Link to="/admin" className={item} title={S.common.console}>
              <Terminal aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
              <span className="sr-only">{S.common.console}</span>
            </Link>
          ) : null}
        </nav>
      </div>
      <div className="flex items-center gap-1.5 sm:flex-col">
        <ThemeToggle className={item} />
        <Link to="/account" className={item} title={account}>
          <User aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
          <span className="sr-only">{account}</span>
        </Link>
        <button type="button" className={item} title={S.common.signOut} onClick={() => void signOut()}>
          <LogOut aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
          <span className="sr-only">{S.common.signOut}</span>
        </button>
      </div>
    </header>
  )
}

export function Layout() {
  return (
    <RequireAuth>
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-50 focus:rounded-md focus:bg-panel focus:px-3 focus:py-2 focus:text-ink"
      >
        Skip to content
      </a>
      <div className="flex min-h-screen flex-col gap-3 p-3 sm:flex-row sm:items-start">
        <Rail />
        <main id="main" className="min-w-0 flex-1">
          <div className="mx-auto max-w-5xl px-1 py-3 sm:px-3">
            <Outlet />
          </div>
        </main>
      </div>
    </RequireAuth>
  )
}
