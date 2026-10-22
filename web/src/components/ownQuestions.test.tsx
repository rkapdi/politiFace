import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const save = vi.fn()
const retire = vi.fn()

vi.mock('../lib/api', () => ({
  useOwnQuestions: () => ({
    data: [
      {
        id: 'own1',
        stem: 'Which amendment lowered the voting age to 18?',
        domain_id: 2,
        options: [
          { key: 'A', text: 'The 19th' },
          { key: 'B', text: 'The 26th' },
        ],
      },
    ],
    isPending: false,
    error: null,
  }),
  useDomains: () => ({
    data: [
      { id: 1, code: 'D1', name: 'American Democracy' },
      { id: 2, code: 'D2', name: 'U.S. Constitution' },
    ],
    isPending: false,
    error: null,
  }),
  useSaveOwnQuestion: () => ({ mutate: save, isPending: false, error: null }),
  useRetireOwnQuestion: () => ({ mutate: retire, isPending: false, error: null }),
}))

import { OwnQuestions } from './OwnQuestions'

describe('OwnQuestions', () => {
  beforeEach(() => {
    save.mockClear()
    retire.mockClear()
  })

  it('creates a question from the form', async () => {
    render(<OwnQuestions cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /add a question/i }))
    await userEvent.type(
      screen.getByLabelText(/^question$/i),
      'How many justices sit on the Supreme Court?',
    )
    await userEvent.selectOptions(screen.getByLabelText(/fcle domain/i), '2')
    await userEvent.type(screen.getByLabelText('Option A'), 'Seven')
    await userEvent.type(screen.getByLabelText('Option B'), 'Nine')
    await userEvent.click(screen.getByLabelText('Option B is correct'))
    await userEvent.click(screen.getByRole('button', { name: /save question/i }))

    expect(save).toHaveBeenCalledTimes(1)
    expect(save.mock.calls[0][0]).toMatchObject({
      cohortId: 'c1',
      domainId: 2,
      stem: 'How many justices sit on the Supreme Court?',
      options: [
        { key: 'A', text: 'Seven' },
        { key: 'B', text: 'Nine' },
      ],
      answerKey: 'B',
      replaces: undefined,
    })
  })

  it('refuses to save without a correct answer', async () => {
    render(<OwnQuestions cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /add a question/i }))
    await userEvent.type(
      screen.getByLabelText(/^question$/i),
      'How many justices sit on the Supreme Court?',
    )
    await userEvent.type(screen.getByLabelText('Option A'), 'Seven')
    await userEvent.type(screen.getByLabelText('Option B'), 'Nine')
    await userEvent.click(screen.getByRole('button', { name: /save question/i }))

    expect(save).not.toHaveBeenCalled()
    expect(screen.getByRole('alert')).toHaveTextContent(/correct answer/i)
  })

  it('editing prefills the wording and replaces the old version', async () => {
    render(<OwnQuestions cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /^edit/i }))
    expect(screen.getByLabelText(/^question$/i)).toHaveValue(
      'Which amendment lowered the voting age to 18?',
    )
    expect(screen.getByLabelText('Option B')).toHaveValue('The 26th')
    await userEvent.click(screen.getByLabelText('Option B is correct'))
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }))

    expect(save.mock.calls[0][0]).toMatchObject({
      answerKey: 'B',
      replaces: 'own1',
    })
  })

  it('removes a question only after confirmation', async () => {
    render(<OwnQuestions cohortId="c1" />)
    await userEvent.click(screen.getByRole('button', { name: /^remove/i }))
    expect(retire).not.toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: /^remove$/i }))
    expect(retire.mock.calls[0][0]).toEqual({
      cohortId: 'c1',
      questionId: 'own1',
    })
  })
})
