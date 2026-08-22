import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const { signInAnonymously, joinLiveSessionGuest } = vi.hoisted(() => ({
  signInAnonymously: vi.fn(async () => ({ user: { id: 'g1' } })),
  joinLiveSessionGuest: vi.fn(async () => ({
    id: 's1',
    title: 'Week 3 quiz',
    status: 'lobby',
    index: -1,
    total: 5,
    question_seconds: 20,
  })),
}))

vi.mock('../lib/api', () => ({
  signInAnonymously,
  joinLiveSessionGuest,
  getLiveQuestion: vi.fn(),
  submitLiveAnswer: vi.fn(),
  liveReveal: vi.fn(),
  liveScoreboard: vi.fn(async () => []),
}))
vi.mock('../lib/live', () => ({
  useLiveSession: () => ({ state: { status: 'lobby' }, error: null }),
  useNow: () => Date.now(),
  secondsLeft: () => 20,
}))

import { JoinPage } from './JoinPage'

describe('JoinPage', () => {
  it('joins with code and name, then waits in the lobby', async () => {
    render(<JoinPage />)
    await userEvent.type(screen.getByLabelText(/session code/i), 'abc123')
    await userEvent.type(screen.getByLabelText(/your name/i), 'Alex R')
    await userEvent.click(screen.getByRole('button', { name: /join/i }))
    expect(signInAnonymously).toHaveBeenCalled()
    expect(joinLiveSessionGuest).toHaveBeenCalledWith('ABC123', 'Alex R')
    expect(
      await screen.findByText(/waiting for your instructor to start/i),
    ).toBeInTheDocument()
  })

  it('shows a friendly error for a bad code', async () => {
    joinLiveSessionGuest.mockRejectedValueOnce(
      new Error(
        'That code does not match a running session. Check it with your instructor.',
      ),
    )
    render(<JoinPage />)
    await userEvent.type(screen.getByLabelText(/session code/i), 'zzz999')
    await userEvent.type(screen.getByLabelText(/your name/i), 'Alex R')
    await userEvent.click(screen.getByRole('button', { name: /join/i }))
    const alert = await screen.findByRole('alert')
    expect(alert).toHaveTextContent(/does not match a running session/i)
  })
})
