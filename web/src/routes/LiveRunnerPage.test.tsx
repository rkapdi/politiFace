import { describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'

vi.mock('../lib/api', () => ({
  liveReveal: vi.fn(),
  liveScoreboard: vi.fn(async () => []),
  useAdvanceLiveSession: () => ({ mutate: vi.fn(), isPending: false }),
  useEndLiveSession: () => ({ mutate: vi.fn(), isPending: false }),
  useLiveSessionMeta: () => ({
    data: { id: 's1', title: 'Week 3 quiz', status: 'ended', join_code: 'ABC123', question_seconds: 20 },
    isPending: false,
    error: null,
  }),
  useLogExport: () => ({ mutate: vi.fn() }),
  useParticipantCount: () => ({ data: 2 }),
  useSessionStats: () => ({ data: [], isPending: false, error: null }),
  useSessionReport: () => ({
    data: [
      { user_id: 'u1', roster_name: 'Maria Lopez', handle: 'm', score: 356, correct_count: 3, answered: 7, per_question: {}, student_ref: 'u1' },
      { user_id: 'u2', roster_name: 'Alex Rivera', handle: 'a', score: 0, correct_count: 0, answered: 0, per_question: {}, student_ref: 'u2' },
    ],
    isPending: false,
    error: null,
  }),
}))
vi.mock('../lib/live', () => ({
  useLiveSession: () => ({ state: { status: 'ended' }, error: null }),
}))

import { LiveRunner } from './LiveRunnerPage'

describe('LiveRunner ended report', () => {
  it('shows correct/answered, and says when a student joined but never answered', () => {
    render(<LiveRunner cohortId="c1" sessionId="s1" />)
    const maria = screen.getByRole('row', { name: /maria lopez/i })
    expect(within(maria).getByText('3/7')).toBeInTheDocument()
    const alex = screen.getByRole('row', { name: /alex rivera/i })
    expect(within(alex).getByText(/joined, no answers/i)).toBeInTheDocument()
    expect(within(alex).queryByText('0/0')).toBeNull()
  })
})
