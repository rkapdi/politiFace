import {
  createHashHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Outlet,
} from '@tanstack/react-router'
import { Layout } from './Layout'
import { ClassesPage } from './ClassesPage'
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

const routeTree = rootRoute.addChildren([
  joinRoute,
  shellRoute.addChildren([classesRoute, classRoute, studentRoute, liveRoute]),
])

export const router = createRouter({
  routeTree,
  history: createHashHistory(),
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}
