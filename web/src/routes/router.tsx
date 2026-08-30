import {
  createHashHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Outlet,
} from '@tanstack/react-router'
import { Layout } from './Layout'
import { Button, Card } from '../components/ui'
import { S } from '../lib/strings'
import { ClassesPage } from './ClassesPage'
import { StyleguidePage } from './StyleguidePage'
import { ClassPage } from './ClassPage'
import { StudentPage } from './StudentPage'
import { LiveRunnerPage } from './LiveRunnerPage'
import { JoinPage } from './JoinPage'

const rootRoute = createRootRoute({ component: Outlet })

// Public: students join live sessions here with no account.
const joinRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/join',
  component: JoinPage,
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
  component: ClassesPage,
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

const styleguideRoute = createRoute({
  getParentRoute: () => shellRoute,
  path: '/styleguide',
  component: StyleguidePage,
})

const routeTree = rootRoute.addChildren([
  joinRoute,
  shellRoute.addChildren([
    classesRoute,
    classRoute,
    studentRoute,
    liveRoute,
    styleguideRoute,
  ]),
])

// A rendering error in one route never becomes a blank page.
function RouteError() {
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
