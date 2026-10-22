// Automated WCAG checks (axe-core) on the highest-traffic screens.
// Violations fail the build; the manual keyboard and screen-reader pass is
// tracked in docs/compliance/.
import { describe, expect, it, vi } from 'vitest'
import { render } from '@testing-library/react'
import { axe } from 'vitest-axe'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

vi.mock('./lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: async () => ({ data: { session: null } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      signInWithOtp: vi.fn(),
      verifyOtp: vi.fn(),
    },
  },
}))

vi.mock('./lib/api', () => ({
  useMyClasses: () => ({
    data: [
      {
        cohort_id: 'c1',
        name: 'POS2041 Fall',
        term: '2026F',
        students: 32,
        active_7d: 21,
        answers_total: 480,
        accuracy: 0.71,
        mocks_completed: 12,
        live_sessions: 3,
      },
    ],
    isPending: false,
    error: null,
  }),
  useReportingPolicy: () => ({
    data: {
      resolution: 'per_student',
      identity_display: 'roster',
      raw_retention_days: null,
      effective: 'per_student',
    },
    isPending: false,
    error: null,
  }),
  useSetReportingPolicy: () => ({
    mutate: vi.fn(),
    isPending: false,
    isSuccess: false,
    error: null,
  }),
  useAddTa: () => ({ mutate: vi.fn(), isPending: false, error: null }),
  useRemoveTa: () => ({ mutate: vi.fn(), isPending: false }),
  useAddCoFaculty: () => ({ mutate: vi.fn(), isPending: false, error: null }),
  useCohortTas: () => ({ data: [], isPending: false, error: null }),
  useCreateCohort: () => ({
    mutate: vi.fn(),
    isPending: false,
    data: undefined,
    error: null,
  }),
  ensureProfile: vi.fn(),
  signInAnonymously: vi.fn(),
  joinLiveSessionGuest: vi.fn(),
  liveSessionPreview: vi.fn(),
  joinLiveSession: vi.fn(),
  joinLiveSessionAsStudent: vi.fn(),
  getLiveQuestion: vi.fn(),
  submitLiveAnswer: vi.fn(),
  liveReveal: vi.fn(),
  liveScoreboard: vi.fn(async () => []),
  useMyConsoleRole: () => ({ data: 'faculty' }),
  useAmVerifiedFaculty: () => ({ data: true, isPending: false, error: null }),
  useMintFacultyInvite: () => ({ mutate: vi.fn(), isPending: false, error: null }),
  inviteLink: (c: string) => c,
  useFacultyRequests: () => ({ data: [], isPending: false, error: null }),
  useDecideFacultyRequest: () => ({ mutate: vi.fn(), isPending: false }),
}))
vi.mock('./lib/live', () => ({
  useLiveSession: () => ({ state: { status: 'lobby' }, error: null }),
  useNow: () => Date.now(),
  secondsLeft: () => 20,
}))
vi.mock('./auth/SessionProvider', () => ({
  useSession: () => ({ session: null, loading: false, signOut: vi.fn() }),
}))

import { SignIn } from './auth/SignIn'
import { ClassesPage } from './routes/ClassesPage'
import { JoinPage } from './routes/JoinPage'
import { SettingsTab } from './components/SettingsTab'
import { StyleguidePage } from './routes/StyleguidePage'

async function expectNoViolations(ui: React.ReactElement) {
  const { container } = render(ui)
  const results = await axe(container)
  expect(results.violations).toEqual([])
}

describe('accessibility', () => {
  it('sign-in screen has no axe violations', async () => {
    await expectNoViolations(<SignIn />)
  })

  it('classes dashboard has no axe violations', async () => {
    await expectNoViolations(<ClassesPage />)
  })

  it('guest join form has no axe violations', async () => {
    window.location.hash = '#/join'
    await expectNoViolations(
      <QueryClientProvider client={new QueryClient()}>
        <JoinPage />
      </QueryClientProvider>,
    )
  })

  it('settings tab has no axe violations', async () => {
    await expectNoViolations(<SettingsTab cohortId="c1" />)
  })

  it('the styleguide (every component, every state) has no axe violations', async () => {
    await expectNoViolations(<StyleguidePage />)
  })
})
