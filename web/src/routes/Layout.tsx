import { Link, Outlet } from '@tanstack/react-router'
import { RequireAuth } from '../auth/RequireAuth'
import { useSession } from '../auth/SessionProvider'
import { Button } from '../components/ui'

function Nav() {
  const { signOut } = useSession()
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
          </nav>
        </div>
        <Button variant="ghost" onClick={() => void signOut()}>
          Sign out
        </Button>
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
