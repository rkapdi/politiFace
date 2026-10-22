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
