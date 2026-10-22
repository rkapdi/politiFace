import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'

const create = vi.fn()
vi.mock('../lib/api', () => ({
  usePickableQuestions: () => ({
    data: [{ id: 'q1', stem: 'Which article establishes the judiciary?', domain_id: 2, cohort_id: null }],
    isPending: false,
    error: null,
  }),
  useDomains: () => ({ data: [{ id: 2, name: 'U.S. Constitution' }], isPending: false }),
  useCreateLiveSession: () => ({ mutate: create, isPending: false, error: null }),
  useCohortSessions: () => ({ data: [], isPending: false, error: null }),
  useCohortRole: () => ({ data: 'faculty', isPending: false, error: null }),
  useOwnQuestions: () => ({ data: [], isPending: false, error: null }),
}))

import { QuestionPicker } from './QuestionPicker'
import { parseGoal } from '../lib/liveOptions'
import { emptyLiveDraft } from './LiveTab'

function Harness() {
  const [draft, setDraft] = useState({ ...emptyLiveDraft(), composing: true })
  return <QuestionPicker cohortId="c1" draft={draft} onDraftChange={setDraft} onCreated={() => {}} />
}

describe('QuestionPicker guests', () => {
  it('defaults to no guests and passes the toggle through', async () => {
    render(<Harness />)
    const guests = screen.getByLabelText(/allow guests without sign-in/i)
    expect(guests).not.toBeChecked()
    await userEvent.type(screen.getByLabelText(/session title/i), 'Friday review')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(guests)
    await userEvent.click(screen.getByRole('button', { name: /start session/i }))
    expect(create.mock.calls[0][0]).toMatchObject({ allowGuests: true, title: 'Friday review' })
  })
})

describe('QuestionPicker scoring options', () => {
  it('defaults to no speed bonus and no goal', async () => {
    create.mockClear()
    render(<Harness />)
    expect(screen.getByLabelText(/speed bonus/i)).not.toBeChecked()
    await userEvent.type(screen.getByLabelText(/session title/i), 'Quiz')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(screen.getByRole('button', { name: /start session/i }))
    expect(create.mock.calls[0][0]).toMatchObject({ speedBonus: false, goalPct: null })
  })

  it('passes the speed bonus and a goal through', async () => {
    create.mockClear()
    render(<Harness />)
    await userEvent.type(screen.getByLabelText(/session title/i), 'Quiz')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(screen.getByLabelText(/speed bonus/i))
    await userEvent.type(screen.getByLabelText(/class goal/i), '75')
    await userEvent.click(screen.getByRole('button', { name: /start session/i }))
    expect(create.mock.calls[0][0]).toMatchObject({ speedBonus: true, goalPct: 75 })
  })

  it('blocks an out-of-range goal with a text explanation', async () => {
    create.mockClear()
    render(<Harness />)
    await userEvent.type(screen.getByLabelText(/session title/i), 'Quiz')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.type(screen.getByLabelText(/class goal/i), '150')
    expect(screen.getByRole('button', { name: /start session/i })).toBeDisabled()
    expect(screen.getByText(/between 1 and 100 percent/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/class goal/i)).toHaveAttribute('aria-invalid', 'true')
  })
})

describe('parseGoal', () => {
  it('accepts whole numbers 1 to 100 and blank', () => {
    expect(parseGoal('')).toBeNull()
    expect(parseGoal(' 70 ')).toBe(70)
    expect(parseGoal('1')).toBe(1)
    expect(parseGoal('100')).toBe(100)
    expect(parseGoal('0')).toBeNull()
    expect(parseGoal('101')).toBeNull()
    expect(parseGoal('7.5')).toBeNull()
  })
})
