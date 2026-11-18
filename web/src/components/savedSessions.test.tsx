import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'
import { useState } from 'react'

type Handlers = { onSuccess?: (r: unknown) => void; onError?: (e: Error) => void }

const m = vi.hoisted(() => ({
  saved: { data: [] as unknown[] | null, isPending: false, error: null as Error | null },
  create: vi.fn(),
  save: vi.fn(),
  start: vi.fn(),
  remove: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  usePickableQuestions: () => ({
    data: [
      { id: 'q1', stem: 'Which article establishes the judiciary?', domain_id: 2, cohort_id: null },
      { id: 'q2', stem: 'What is a democracy?', domain_id: 1, cohort_id: null },
    ],
    isPending: false,
    error: null,
  }),
  useDomains: () => ({
    data: [
      { id: 1, name: 'American Democracy' },
      { id: 2, name: 'U.S. Constitution' },
    ],
    isPending: false,
  }),
  useCreateLiveSession: () => ({ mutate: m.create, isPending: false, error: null }),
  useCohortSessions: () => ({ data: [], isPending: false, error: null }),
  // A TA: runs sessions, does not author questions.
  useCohortRole: () => ({ data: 'ta', isPending: false, error: null }),
}))
vi.mock('../lib/liveDrafts', async importOriginal => ({
  ...(await importOriginal<typeof import('../lib/liveDrafts')>()),
  useSavedSessions: () => m.saved,
  useSaveSession: () => ({ mutate: m.save, isPending: false, error: null }),
  useStartSavedSession: () => ({ mutate: m.start, isPending: false, error: null }),
  useDeleteSavedSession: () => ({ mutate: m.remove, isPending: false, error: null }),
}))

import { LiveTab, emptyLiveDraft } from './LiveTab'
import { fromLocalInput, toLocalInput } from '../lib/liveDrafts'

const review = {
  id: 'd1',
  title: 'Unit 3 review',
  question_ids: ['q1', 'q2'],
  question_count: 2,
  question_seconds: 30,
  allow_guests: true,
  planned_for: '2026-11-20T15:30:00Z',
  created_at: '2026-11-17T12:00:00Z',
  updated_at: '2026-11-17T12:00:00Z',
  created_by: 'prof_rivera',
  locked_now: 0,
  started_at: null,
  started_session: null,
}
const held = {
  ...review,
  id: 'd2',
  title: 'Courts check-in',
  allow_guests: false,
  planned_for: null,
  locked_now: 2,
}

function Harness() {
  const [draft, setDraft] = useState(emptyLiveDraft())
  return <LiveTab cohortId="c1" draft={draft} onDraftChange={setDraft} />
}

const setUp = () => userEvent.click(screen.getByRole('button', { name: /set one up/i }))
const list = () => screen.getByRole('heading', { name: /saved sessions/i }).closest('div')!
const row = (title: string) => screen.getByText(title).closest('li')!

beforeEach(() => {
  m.saved = { data: [], isPending: false, error: null }
  for (const f of [m.create, m.save, m.start, m.remove]) f.mockReset()
  window.location.hash = ''
})

describe('saved live sessions', () => {
  it('stays out of the way until the server has the feature', async () => {
    m.saved = { data: null, isPending: false, error: null }
    render(<Harness />)
    expect(screen.queryByRole('heading', { name: /saved sessions/i })).toBeNull()
    await setUp()
    expect(screen.queryByRole('button', { name: /save for later/i })).toBeNull()
    expect(screen.queryByLabelText(/planned for/i)).toBeNull()
    expect(screen.getByRole('button', { name: /start session/i })).toBeInTheDocument()
  })

  it('saves a session for later with its planned time, then says where to find it', async () => {
    m.save.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'd9', question_count: 1, locked_now: 0 }),
    )
    render(<Harness />)
    expect(within(list()).getByText(/nothing saved yet/i)).toBeInTheDocument()
    await setUp()
    await userEvent.type(screen.getByLabelText(/session title/i), '  Unit 3 review ')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    fireEvent.change(screen.getByLabelText(/planned for/i), { target: { value: '2026-11-20T10:30' } })
    await userEvent.click(screen.getByRole('button', { name: /save for later/i }))

    expect(m.create).not.toHaveBeenCalled()
    expect(m.save.mock.calls[0][0]).toEqual({
      cohortId: 'c1',
      title: 'Unit 3 review',
      questionIds: ['q1'],
      questionSeconds: 20,
      allowGuests: false,
      plannedFor: new Date('2026-11-20T10:30').toISOString(),
      draftId: null,
    })
    expect(screen.getByRole('status')).toHaveTextContent(/saved\. start it from saved sessions/i)
    // The form closes, and the next session starts from a blank one.
    expect(screen.queryByLabelText(/session title/i)).toBeNull()
    await setUp()
    expect(screen.getByLabelText(/session title/i)).toHaveValue('')
    expect(screen.getByText('0 selected')).toBeInTheDocument()
  })

  it('warns at once when a saved session holds reserved questions', async () => {
    m.save.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'd9', question_count: 1, locked_now: 1 }),
    )
    render(<Harness />)
    await setUp()
    await userEvent.type(screen.getByLabelText(/session title/i), 'Unit 3 review')
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(screen.getByRole('button', { name: /save for later/i }))
    expect(screen.getByText(/1 question is reserved for a retention check/i)).toBeInTheDocument()
  })

  it('does not save without a title', async () => {
    render(<Harness />)
    await setUp()
    await userEvent.click(screen.getByRole('checkbox', { name: /judiciary/i }))
    await userEvent.click(screen.getByRole('button', { name: /save for later/i }))
    expect(m.save).not.toHaveBeenCalled()
  })

  it('lists saved sessions and starts one straight into the host view', async () => {
    m.saved = { data: [review, held], isPending: false, error: null }
    m.start.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 's77', join_code: 'ABC123', question_count: 2, draft_id: 'd1' }),
    )
    render(<Harness />)
    const first = row('Unit 3 review')
    expect(within(first).getByText(/2 questions, 30 seconds each, guests allowed/)).toBeInTheDocument()
    expect(within(first).getByText(/planned for .*saved by prof_rivera/i)).toBeInTheDocument()
    expect(within(row('Courts check-in')).getByText(/no date set/i)).toBeInTheDocument()

    await userEvent.click(within(first).getByRole('button', { name: /^start$/i }))
    expect(m.start.mock.calls[0][0]).toEqual({ cohortId: 'c1', draftId: 'd1' })
    expect(window.location.hash).toBe('#/class/c1/live/s77')
  })

  it('will not start a session whose questions are reserved, and says why', () => {
    m.saved = { data: [held], isPending: false, error: null }
    render(<Harness />)
    const r = row('Courts check-in')
    expect(within(r).getByText(/2 questions are reserved for a retention check/i)).toBeInTheDocument()
    expect(within(r).getByRole('button', { name: /^start$/i })).toBeDisabled()
  })

  it('shows why a start was refused and keeps the session saved', async () => {
    m.saved = { data: [review], isPending: false, error: null }
    m.start.mockImplementation((_a: unknown, h: Handlers) =>
      h.onError?.(new Error('That saved session was already started. Look under Past sessions.')),
    )
    render(<Harness />)
    await userEvent.click(within(row('Unit 3 review')).getByRole('button', { name: /^start$/i }))
    expect(screen.getByRole('alert')).toHaveTextContent(/already started/i)
    expect(window.location.hash).toBe('')
  })

  it('edits a saved session in the same form, where the only way out is to save', async () => {
    m.saved = { data: [review], isPending: false, error: null }
    m.save.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'd1', question_count: 2, locked_now: 0 }),
    )
    render(<Harness />)
    await userEvent.click(within(row('Unit 3 review')).getByRole('button', { name: /^edit$/i }))

    const title = screen.getByLabelText(/session title/i)
    expect(title).toHaveValue('Unit 3 review')
    expect(screen.getByText('2 selected')).toBeInTheDocument()
    expect(screen.getByRole('combobox', { name: /seconds per question/i })).toHaveValue('30')
    expect(screen.getByRole('checkbox', { name: /allow guests/i })).toBeChecked()
    expect(screen.getByLabelText(/planned for/i)).toHaveValue(toLocalInput(review.planned_for))
    expect(screen.queryByRole('button', { name: /start session/i })).toBeNull()
    // The row says it is being edited and cannot be started mid-edit.
    const r = row('Unit 3 review')
    expect(within(r).getByText('editing')).toBeInTheDocument()
    expect(within(r).getByRole('button', { name: /^start$/i })).toBeDisabled()

    // Enter in the title must save, never open a lobby.
    await userEvent.type(title, ' (B){Enter}')
    expect(m.create).not.toHaveBeenCalled()
    expect(m.save.mock.calls[0][0]).toMatchObject({
      title: 'Unit 3 review (B)',
      questionIds: ['q1', 'q2'],
      questionSeconds: 30,
      allowGuests: true,
      draftId: 'd1',
    })
  })

  it('cancelling an edit drops it, so the next session starts blank', async () => {
    m.saved = { data: [review], isPending: false, error: null }
    render(<Harness />)
    await userEvent.click(within(row('Unit 3 review')).getByRole('button', { name: /^edit$/i }))
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }))
    await setUp()
    expect(screen.getByLabelText(/session title/i)).toHaveValue('')
    expect(screen.getByRole('button', { name: /start session/i })).toBeInTheDocument()
    expect(m.save).not.toHaveBeenCalled()
  })

  it('names questions that have left the bank and lets them be removed', async () => {
    m.saved = {
      data: [{ ...review, question_ids: ['q1', 'gone-1'], question_count: 2 }],
      isPending: false,
      error: null,
    }
    render(<Harness />)
    await userEvent.click(within(row('Unit 3 review')).getByRole('button', { name: /^edit$/i }))
    expect(screen.getByText(/1 question in this session is no longer in the question bank/i)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /remove from the session/i }))
    expect(screen.getByText('1 selected')).toBeInTheDocument()
    expect(screen.queryByText(/no longer in the question bank/i)).toBeNull()
  })

  it('asks before deleting, with Keep as the safe choice', async () => {
    m.saved = { data: [review], isPending: false, error: null }
    render(<Harness />)
    const r = row('Unit 3 review')
    await userEvent.click(within(r).getByRole('button', { name: /^delete$/i }))
    const confirm = within(r).getByRole('group', { name: /confirm deleting/i })
    expect(within(confirm).getByText(/delete the saved session "Unit 3 review"\?/i)).toBeInTheDocument()
    expect(within(confirm).getByRole('button', { name: /^keep$/i })).toHaveFocus()
    expect(m.remove).not.toHaveBeenCalled()

    await userEvent.click(within(confirm).getByRole('button', { name: /^keep$/i }))
    expect(within(r).getByRole('button', { name: /^delete$/i })).toHaveFocus()

    await userEvent.click(within(r).getByRole('button', { name: /^delete$/i }))
    await userEvent.click(
      within(within(r).getByRole('group', { name: /confirm deleting/i })).getByRole('button', { name: /^delete$/i }),
    )
    expect(m.remove.mock.calls[0][0]).toEqual({ cohortId: 'c1', draftId: 'd1' })
  })

  it('round-trips a planned time through the date field', () => {
    expect(toLocalInput(null)).toBe('')
    expect(fromLocalInput('')).toBeNull()
    expect(fromLocalInput('not a date')).toBeNull()
    const iso = '2026-11-20T15:30:00.000Z'
    expect(fromLocalInput(toLocalInput(iso))).toBe(iso)
  })

  it('has no accessibility violations, in the list or while editing', async () => {
    m.saved = { data: [review, held], isPending: false, error: null }
    const { container } = render(<Harness />)
    expect((await axe(container)).violations).toEqual([])
    await userEvent.click(within(row('Unit 3 review')).getByRole('button', { name: /^edit$/i }))
    expect((await axe(container)).violations).toEqual([])
  })
})
