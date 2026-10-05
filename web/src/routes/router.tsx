import { useEffect } from 'react'
import {
  createHashHistory,
  createRootRoute,
  createRoute,
  createRouter,
  lazyRouteComponent,
  Outlet,
} from '@tanstack/react-router'
import { Layout } from './Layout'
import { Button, Card } from '../components/ui'
import { S } from '../lib/strings'
import { logOpsEvent } from '../lib/opsLog'
import { HomePage } from './HomePage'
import { StyleguidePage } from './StyleguidePage'
import { ClassPage } from './ClassPage'
import { StudentPage } from './StudentPage'
import { LiveRunnerPage } from './LiveRunnerPage'
import { JoinPage } from './JoinPage'
import { AccountPage } from './AccountPage'
import { WelcomePage } from './WelcomePage'

const rootRoute = createRootRoute({ component: Outlet })

// Public: students join live sessions here with no account.
const joinRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/join',
  component: JoinPage,
})

// Public: professors land here from an invite link and sign in on the page.
const welcomeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/welcome',
  component: WelcomePage,
})

// Everything else is the authenticated faculty console.
const shellRoute = createRoute({
  getParentRoute: () => rootRoute,
  id: 'shell',
  component: Layout,
})

const classesRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/',
  component: HomePage,
})

const classRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/class/$cohortId',
  component: ClassPage,
})

const studentRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/class/$cohortId/student/$studentRef',
  component: StudentPage,
})

const liveRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/class/$cohortId/live/$sessionId',
  component: LiveRunnerPage,
})

const accountRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/account',
  component: AccountPage,
})

const styleguideRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/styleguide',
  component: StyleguidePage,
})

// The admin console: a separate dark shell for the two founders, lazy
// loaded so its code never ships to students or faculty. `AdminLayout`
// (the lazy-loaded export) wraps its own RequireAuth, so the route itself
// is the thing TanStack Router preloads: no synchronous wrapper mounts
// before the chunk arrives.
const adminRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/admin',
  component: lazyRouteComponent(() => import('../admin/AdminLayout'), 'AdminLayout'),
})
const adminHomeRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/',
  component: lazyRouteComponent(() => import('../admin/AdminHome'), 'AdminHome'),
})
const adminSearchRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/search',
  component: lazyRouteComponent(() => import('../admin/SearchPage'), 'SearchPage'),
})
const adminPersonRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/people/$userId',
  component: lazyRouteComponent(() => import('../admin/PersonPage'), 'PersonPage'),
})
const adminClassRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/classes/$cohortId',
  component: lazyRouteComponent(() => import('../admin/ClassRecordPage'), 'ClassRecordPage'),
})
const adminSessionRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/sessions/$sessionId',
  component: lazyRouteComponent(() => import('../admin/SessionRecordPage'), 'SessionRecordPage'),
})
const adminInvitesRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/invites',
  component: lazyRouteComponent(() => import('../admin/InvitesPage'), 'InvitesPage'),
})
const adminAuditRoute = createRoute({
  getParentRoute: () => adminRoute,
  path: '/audit',
  component: lazyRouteComponent(() => import('../admin/AuditPage'), 'AuditPage'),
})

const routeTree = rootRoute.addChildren([
  joinRoute,
  welcomeRoute,
  shellRoute.addChildren([
    classesRoute,
    classRoute,
    studentRoute,
    liveRoute,
    accountRoute,
    styleguideRoute,
  ]),
  adminRoute.addChildren([
    adminHomeRoute,
    adminSearchRoute,
    adminPersonRoute,
    adminClassRoute,
    adminSessionRoute,
    adminInvitesRoute,
    adminAuditRoute,
  ]),
])

// A rendering error in one route never becomes a blank page.
function RouteError({ error }: { error: unknown }) {
  useEffect(() => {
    logOpsEvent('client_error', {
      code: 'route_error',
      detail: {
        route: window.location.hash.slice(0, 120),
        message: String((error as Error)?.message ?? error).slice(0, 300),
      },
    })
  }, [error])
  return (
    <Card className="mx-auto mt-16 max-w-md text-center">
      <p className="text-sm text-slate-700">{S.errors.somethingBroke}</p>
      <div className="mt-3">
        <Button onClick={() => window.location.reload()}>
          {S.common.reload}
        </Button>
      </div>
    </Card>
  )
}

export const router = createRouter({
  routeTree,
  history: createHashHistory(),
  defaultErrorComponent: RouteError,
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}
