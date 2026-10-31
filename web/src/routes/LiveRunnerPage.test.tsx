import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactElement } from 'react'

const m = vi.hoisted(() => ({
  state: { status: 'ended' } as Record<string, unknown>,
  role: 'faculty',
  advance: vi.fn(),
  end: vi.fn(),
  advanceError: null as null | Error,
}))

vi.mock('../lib/api', () => ({
  liveReveal: vi.fn(async () => ({ counts: {}, correct_key: 'a', explanation: null })),
  liveScoreboard: vi.fn(async () => [
    { rank: 1, handle: 'Maria Lopez', score: 356, is_me: false },
  ]),
  useAdvanceLiveSession: () => ({ mutate: m.advance, isPending: false, error: m.advanceError }),
  useEndLiveSession: () => ({ mutate: m.end, isPending: false, error: null }),
  useCohortRole: () => ({ data: m.role }),
  useAnsweredCount: (_s: string, _q: string, enabled: boolean) => ({
    data: enabled ? 12 : undefined,
  }),
  useLiveSessionMeta: () => ({
    data: { id: 's1', title: 'Week 3 quiz', status: 'ended', join_code: 'ABC123', question_seconds: 20 },
    isPending: false,
    error: null,
  }),
  useLogExport: () => ({ mutate: vi.fn() }),
  useParticipantCount: () => ({ data: 20 }),
  useSessionStats: () => ({
    data: [
      { question_id: 'q1', stem: 'Which article?', answered: 2, correct_rate: 0.5 },
      { question_id: 'q2', stem: 'Who signs bills?', answered: 2, correct_rate: 1 },
    ],
    isPending: false,
    error: null,
  }),
  useSessionReport: () => ({
    data: [
      { user_id: 'u1', roster_name: 'Maria Lopez', handle: 'm', score: 356, correct_count: 3, answered: 7, per_question: { q1: true, q2: false }, student_ref: 'u1' },
      { user_id: 'u2', roster_name: 'Alex Rivera', handle: 'a', score: 0, correct_count: 0, answered: 0, per_question: {}, student_ref: 'u2' },
    ],
    isPending: false,
    error: null,
  }),
}))
vi.mock('../lib/live', () => ({
  useLiveSession: () => ({ state: m.state, error: null }),
  useNow: () => Date.now(),
  secondsLeft: () => 10,
}))

import { LiveRunner } from './LiveRunnerPage'

const wrap = (ui: ReactElement) =>
  render(<QueryClientProvider client={new QueryClient()}>{ui}</QueryClientProvider>)

const question = {
  status: 'question',
  index: 0,
  total: 2,
  started_at: new Date().toISOString(),
  question_seconds: 20,
  question: { id: 'q1', stem: 'Which article?', options: [{ key: 'a', text: 'One' }] },
}

describe('LiveRunner while running', () => {
  beforeEach(() => {
    m.role = 'faculty'
    m.end.mockClear()
    m.advanceError = null
  })

  it('shows faculty how many have answered', () => {
    m.state = question
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    expect(screen.getByText('12 of 20 answered')).toBeInTheDocument()
  })

  it('hides the count from TAs, who cannot read answers', () => {
    m.state = question
    m.role = 'ta'
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    expect(screen.queryByText(/answered/)).toBeNull()
  })

  it('asks before ending the session for everyone', async () => {
    m.state = question
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    await userEvent.click(screen.getByRole('button', { name: 'End session' }))
    expect(m.end).not.toHaveBeenCalled()
    expect(screen.getByText(/end this session for everyone/i)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /keep running/i }))
    expect(m.end).not.toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: 'End session' }))
    await userEvent.click(screen.getByRole('button', { name: 'End session' }))
    expect(m.end).toHaveBeenCalledWith({ sessionId: 's1' }, expect.anything())
  })

  it('labels the last step as finishing, and has one start button in the lobby', () => {
    m.state = { status: 'reveal', index: 1, total: 2 }
    const { unmount } = wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    expect(screen.getByRole('button', { name: /finish session/i })).toBeInTheDocument()
    unmount()
    m.state = { status: 'lobby' }
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    expect(screen.getAllByRole('button', { name: /start/i })).toHaveLength(1)
  })

  it('says so when advancing fails', () => {
    m.state = question
    m.advanceError = new Error('Something went wrong on our side. Try again.')
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    expect(screen.getByRole('alert')).toHaveTextContent(/something went wrong/i)
  })
})

describe('LiveRunner ended report', () => {
  beforeEach(() => {
    m.state = { status: 'ended' }
    m.role = 'faculty'
  })

  it('shows standings, per-question marks, and a print action', async () => {
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    expect(await screen.findByRole('heading', { name: /final standings/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /print/i })).toBeInTheDocument()
    expect(screen.getByRole('img', { name: 'Question 1: correct' })).toBeInTheDocument()
    expect(screen.getByRole('img', { name: 'Question 2: incorrect' })).toBeInTheDocument()
  })

  it('shows correct/answered, and says when a student joined but never answered', () => {
    wrap(<LiveRunner cohortId="c1" sessionId="s1" />)
    const maria = screen.getByRole('row', { name: /maria lopez/i })
    expect(within(maria).getByText('3/7')).toBeInTheDocument()
    const alex = screen.getByRole('row', { name: /alex rivera/i })
    expect(within(alex).getByText(/joined, no answers/i)).toBeInTheDocument()
    expect(within(alex).queryByText('0/0')).toBeNull()
  })
})
