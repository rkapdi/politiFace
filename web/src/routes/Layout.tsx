import { Link, Outlet } from '@tanstack/react-router'
import { LogOut, User } from 'lucide-react'
import { RequireAuth } from '../auth/RequireAuth'
import { useSession } from '../auth/SessionProvider'
import { useAmAdmin, useMyProfile } from '../lib/api'
import { S } from '../lib/strings'
import { Button } from '../components/ui'

function Nav() {
  const { session, signOut } = useSession()
  const profile = useMyProfile(session?.user.id ?? '')
  const isAdmin = useAmAdmin().data === true
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <div className="flex items-center gap-6">
          <span className="font-semibold text-slate-900">Politiface</span>
          <nav aria-label="Main">
            <Link
              to="/"
              className="text-sm text-slate-600 hover:text-slate-900 [&.active]:font-medium [&.active]:text-slate-900"
            >
              Your classes
            </Link>
            {isAdmin ? (
              <Link to="/admin" className="text-sm text-slate-600 hover:text-slate-900">
                {S.common.console}
              </Link>
            ) : null}
          </nav>
        </div>
        <div className="flex items-center gap-2">
          <Link
            to="/account"
            className="inline-flex items-center gap-2 rounded-md border border-slate-300 px-3.5 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 [&.active]:bg-slate-100"
          >
            <User aria-hidden="true" className="size-4" />
            {profile.data?.handle ?? S.account.title}
          </Link>
          <Button variant="ghost" onClick={() => void signOut()}>
            <LogOut aria-hidden="true" className="size-4" />
            {S.common.signOut}
          </Button>
        </div>
      </div>
    </header>
  )
}

export function Layout() {
  return (
    <RequireAuth>
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-50 focus:rounded focus:bg-white focus:px-3 focus:py-2"
      >
        Skip to content
      </a>
      <Nav />
      <main id="main" className="mx-auto max-w-5xl px-4 py-6">
        <Outlet />
      </main>
    </RequireAuth>
  )
}
