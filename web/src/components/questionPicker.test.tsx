import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'

const create = vi.fn()
vi.mock('../lib/api', () => ({
  usePickableQuestions: () => ({
    data: [
      { id: 'q1', stem: 'Which article establishes the judiciary?', domain_id: 2, cohort_id: null },
      { id: 'q2', stem: 'What is a democracy?', domain_id: 1, cohort_id: null },
      { id: 'q3', stem: 'My own question on the courts', domain_id: 2, cohort_id: 'c1' },
    ],
    isPending: false,
    error: null,
  }),
  useDomains: () => ({
    data: [{ id: 1, name: 'American Democracy' }, { id: 2, name: 'U.S. Constitution' }],
    isPending: false,
  }),
  useCreateLiveSession: () => ({ mutate: create, isPending: false, error: null }),
  useCohortSessions: () => ({ data: [], isPending: false, error: null }),
  useCohortRole: () => ({ data: 'faculty', isPending: false, error: null }),
  useOwnQuestions: () => ({ data: [], isPending: false, error: null }),
}))

import { QuestionPicker } from './QuestionPicker'
import { emptyLiveDraft } from './LiveTab'

function Harness() {
  const [draft, setDraft] = useState({ ...emptyLiveDraft(), composing: true })
  return <QuestionPicker cohortId="c1" draft={draft} onDraftChange={setDraft} onCreated={() => {}} />
}

describe('QuestionPicker filters', () => {
  it('narrows by domain and to own questions, keeping hidden selections', async () => {
    render(<Harness />)
    await userEvent.click(screen.getByRole('checkbox', { name: /democracy/i }))
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /^domain$/i }), 'U.S. Constitution')
    expect(screen.queryByRole('checkbox', { name: /democracy/i })).toBeNull()
    expect(screen.getByRole('checkbox', { name: /judiciary/i })).toBeInTheDocument()
    // The selection survives being filtered out of view.
    expect(screen.getByText('1 selected')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('checkbox', { name: /only my questions/i }))
    expect(screen.queryByRole('checkbox', { name: /judiciary/i })).toBeNull()
    expect(screen.getByRole('checkbox', { name: /my own question/i })).toBeInTheDocument()
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /^domain$/i }), 'American Democracy')
    expect(screen.getByText(/no questions match/i)).toBeInTheDocument()
  })

  it('stops at the 50 questions the server allows', () => {
    const selected = new Set(Array.from({ length: 51 }, (_, i) => `x${i}`))
    render(
      <QuestionPicker
        cohortId="c1"
        draft={{ ...emptyLiveDraft(), composing: true, selected }}
        onDraftChange={() => {}}
        onCreated={() => {}}
      />,
    )
    expect(screen.getByRole('button', { name: /start session/i })).toBeDisabled()
    expect(screen.getByText(/up to 50 questions/i)).toBeInTheDocument()
  })
})

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
