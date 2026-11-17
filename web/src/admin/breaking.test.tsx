import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'

type Handlers = { onSuccess?: (r: unknown) => void; onError?: (e: Error) => void }

const m = vi.hoisted(() => ({
  list: { data: [] as unknown[] | undefined, isPending: false, error: null as Error | null },
  publish: vi.fn(),
  retract: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  friendlyMessage: () => 'Something went wrong. Try again.',
}))
vi.mock('./breakingApi', () => ({
  useBreakingList: () => m.list,
  usePublishBreaking: () => ({ mutate: m.publish, isPending: false }),
  useRetractBreaking: () => ({ mutate: m.retract, isPending: false }),
}))

import { BreakingPage } from './BreakingPage'
import { NOT_DEPLOYED, emptyDraft, explain, sourceHost, validate, type Draft } from './breaking'

const HEADLINE = 'The Secretary of Labor has resigned, the department says.'
const good: Draft = {
  kind: 'resigned',
  headline: HEADLINE,
  detail: '',
  source: 'https://www.dol.gov/newsroom/statement',
  official: false,
  second: 'https://apnews.com/article/labor',
  notify: true,
}

const item = {
  id: 'b1',
  kind: 'removed',
  headline: 'The director of the bureau was removed from the post today.',
  detail: 'The White House confirmed it in a statement.',
  source_url: 'https://www.whitehouse.gov/statement',
  source_is_official: true,
  second_source_url: null,
  notify: true,
  published_at: '2026-11-16T14:05:00Z',
  published_by: 'AdminTwo',
  retracted_at: null,
  retraction_note: null,
}

async function fill(d: Partial<Draft> = {}) {
  const v = { ...good, ...d }
  if (v.kind) await userEvent.click(screen.getByRole('radio', { name: /^resigned$/i }))
  if (v.headline) await userEvent.type(screen.getByLabelText(/^headline$/i), v.headline)
  if (v.source) await userEvent.type(screen.getByLabelText(/first source link/i), v.source)
  if (v.official) await userEvent.click(screen.getByRole('checkbox', { name: /official statement/i }))
  if (v.second) await userEvent.type(screen.getByLabelText(/second source link/i), v.second)
  if (v.notify === true) await userEvent.click(screen.getByRole('radio', { name: /notify every phone/i }))
  if (v.notify === false) await userEvent.click(screen.getByRole('radio', { name: /feed only/i }))
}
const review = () => userEvent.click(screen.getByRole('button', { name: /review before publishing/i }))

beforeEach(() => {
  m.list = { data: [], isPending: false, error: null }
  m.publish.mockReset()
  m.retract.mockReset()
})

describe('breaking desk rules', () => {
  it('accepts two different sources, or one official one', () => {
    expect(validate(good)).toEqual({})
    expect(validate({ ...good, second: '', official: true })).toEqual({})
    expect(validate({ ...good, second: '' }).second).toMatch(/second, different source/i)
    expect(validate({ ...good, second: good.source }).second).toMatch(/second, different source/i)
  })

  it('insists on a kind and on how it goes out', () => {
    const e = validate({ ...emptyDraft, headline: HEADLINE, source: good.source, official: true })
    expect(e.kind).toBeTruthy()
    expect(e.delivery).toBeTruthy()
  })

  it('checks lengths, links and long dashes the way the server does', () => {
    expect(validate({ ...good, headline: 'Too short' }).headline).toMatch(/12 to 160/)
    expect(validate({ ...good, headline: 'x'.repeat(161) }).headline).toMatch(/12 to 160/)
    expect(validate({ ...good, headline: 'He resigned — the office said so.' }).headline).toMatch(/dash/)
    expect(validate({ ...good, detail: 'Context – more context.' }).detail).toMatch(/dash/)
    expect(validate({ ...good, detail: 'x'.repeat(601) }).detail).toMatch(/600/)
    expect(validate({ ...good, source: 'http://example.com' }).source).toMatch(/https/)
    expect(validate({ ...good, second: 'apnews.com' }).second).toMatch(/second source must be an https/i)
  })

  it('puts each server refusal on its field', () => {
    expect(explain('the source must be an https link').field).toBe('source')
    expect(
      explain('a second, different source is required unless the first is an official statement').field,
    ).toBe('second')
    expect(
      explain('use a comma or a full stop instead of a dash', { ...good, detail: 'a — b' }).field,
    ).toBe('detail')
    expect(explain(NOT_DEPLOYED).text).toMatch(/not switched on/i)
    expect(explain('admin only').text).toMatch(/only admins/i)
    expect(explain('something else entirely')).toEqual({ text: 'Something went wrong. Try again.' })
  })

  it('shows a source by its site', () => {
    expect(sourceHost('https://www.dol.gov/newsroom/statement')).toBe('dol.gov')
    expect(sourceHost('not a link')).toBe('not a link')
  })
})

describe('BreakingPage', () => {
  it('shows the two-source rule and the notification before anything is typed', () => {
    render(<BreakingPage />)
    expect(screen.getByText('Two different sources, or one official statement.')).toBeInTheDocument()
    expect(screen.getByText(/source rule not met yet/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/second source link \(required\)/i)).toBeInTheDocument()
    const preview = screen.getByRole('region', { name: /what phones will show/i })
    expect(within(preview).getByText('Breaking')).toBeInTheDocument()
    expect(within(preview).getAllByText(/your headline appears here/i).length).toBeGreaterThan(0)
    // Nothing is chosen for the editor.
    for (const r of screen.getAllByRole('radio')) expect(r).not.toBeChecked()
  })

  it('names what is wrong next to each field and moves to the first problem', async () => {
    render(<BreakingPage />)
    await review()
    expect(screen.getByText('Choose what happened.')).toBeInTheDocument()
    expect(screen.getByText('The headline must be 12 to 160 characters.')).toBeInTheDocument()
    expect(screen.getByText('The source must be an https link.')).toBeInTheDocument()
    expect(screen.getByText('Choose how this goes out.')).toBeInTheDocument()
    expect(screen.getByText(/fix 5 things above first/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/^headline$/i)).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByRole('radio', { name: /removed from a post/i })).toHaveFocus()
    expect(m.publish).not.toHaveBeenCalled()
  })

  it('an official first source makes the second optional', async () => {
    render(<BreakingPage />)
    await fill({ official: true, second: '' })
    expect(screen.getByLabelText(/second source link \(optional\)/i)).toBeInTheDocument()
    expect(screen.getByText(/source rule met/i)).toBeInTheDocument()
    await review()
    expect(screen.getByRole('group', { name: /confirm publishing/i })).toBeInTheDocument()
  })

  it('asks before sending to every phone, then says how fast it goes out', async () => {
    m.publish.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'b9', published_at: '2026-11-16T15:00:00Z', notify: true, kicked: true, duplicate: false }),
    )
    render(<BreakingPage />)
    await fill()
    expect(within(screen.getByRole('region', { name: /what phones will show/i })).getAllByText(HEADLINE).length).toBe(2)
    await review()
    expect(m.publish).not.toHaveBeenCalled()
    const confirm = screen.getByRole('group', { name: /confirm publishing/i })
    expect(within(confirm).getByText(/send this to every phone/i)).toBeInTheDocument()
    expect(within(confirm).getByText(/cannot be recalled/i)).toBeInTheDocument()
    expect(within(confirm).getByText('Breaking')).toBeInTheDocument()
    expect(within(confirm).getByText(HEADLINE)).toBeInTheDocument()
    expect(within(confirm).getByText('dol.gov')).toBeInTheDocument()
    expect(within(confirm).getByText('apnews.com')).toBeInTheDocument()
    // Focus lands on the safe choice, and the fields cannot change underneath.
    expect(screen.getByRole('button', { name: /back to edit/i })).toHaveFocus()
    expect(screen.getByLabelText(/^headline$/i)).toBeDisabled()

    await userEvent.click(screen.getByRole('button', { name: /publish and notify/i }))
    expect(m.publish).toHaveBeenCalledTimes(1)
    expect(m.publish.mock.calls[0][0]).toMatchObject({
      kind: 'resigned',
      headline: HEADLINE,
      source: good.source,
      second: good.second,
      official: false,
      notify: true,
    })
    expect(screen.getByRole('status')).toHaveTextContent('Published. The notification goes out in seconds.')
    expect(screen.getByLabelText(/^headline$/i)).toHaveValue('')
  })

  it('says when the notification waits for the next check', async () => {
    m.publish.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'b9', published_at: '2026-11-16T15:00:00Z', notify: true, kicked: false, duplicate: false }),
    )
    render(<BreakingPage />)
    await fill()
    await review()
    await userEvent.click(screen.getByRole('button', { name: /publish and notify/i }))
    expect(screen.getByRole('status')).toHaveTextContent(/at most 5 minutes/i)
  })

  it('feed only is its own choice, with its own confirmation and result', async () => {
    m.publish.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'b9', published_at: '2026-11-16T15:00:00Z', notify: false, kicked: false, duplicate: false }),
    )
    render(<BreakingPage />)
    await fill({ notify: false })
    expect(screen.getByText(/no notification\. this item goes to the feed only/i)).toBeInTheDocument()
    await review()
    const confirm = screen.getByRole('group', { name: /confirm publishing/i })
    expect(within(confirm).getByText(/add this to the feed/i)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /publish to the feed/i }))
    expect(m.publish.mock.calls[0][0]).toMatchObject({ notify: false })
    expect(screen.getByRole('status')).toHaveTextContent(/no notification was sent/i)
  })

  it('a repeat of the same headline is reported as already published', async () => {
    m.publish.mockImplementation((_a: unknown, h: Handlers) =>
      h.onSuccess?.({ id: 'b9', published_at: '2026-11-16T15:00:00Z', notify: true, kicked: false, duplicate: true }),
    )
    render(<BreakingPage />)
    await fill()
    await review()
    await userEvent.click(screen.getByRole('button', { name: /publish and notify/i }))
    expect(screen.getByRole('status')).toHaveTextContent(/already published/i)
    expect(screen.queryByText(/goes out in seconds/i)).not.toBeInTheDocument()
  })

  it('going back keeps the draft', async () => {
    render(<BreakingPage />)
    await fill()
    await review()
    await userEvent.click(screen.getByRole('button', { name: /back to edit/i }))
    expect(screen.getByLabelText(/^headline$/i)).toHaveValue(HEADLINE)
    expect(screen.getByRole('button', { name: /review before publishing/i })).toHaveFocus()
    expect(m.publish).not.toHaveBeenCalled()
  })

  it('a server refusal returns to the form, on the field it names', async () => {
    m.publish.mockImplementation((_a: unknown, h: Handlers) =>
      h.onError?.(new Error('the second source must be an https link')),
    )
    render(<BreakingPage />)
    await fill()
    await review()
    await userEvent.click(screen.getByRole('button', { name: /publish and notify/i }))
    expect(screen.getByText('The second source must be an https link.')).toBeInTheDocument()
    expect(screen.getByLabelText(/second source link/i)).toHaveFocus()
    expect(screen.getByLabelText(/^headline$/i)).toHaveValue(HEADLINE)
  })

  it('lists what was published and warns before a retraction', async () => {
    m.list = {
      data: [
        item,
        {
          ...item,
          id: 'b2',
          kind: 'other',
          headline: 'An earlier report about the bureau was wrong.',
          notify: false,
          source_is_official: false,
          second_source_url: 'https://apnews.com/article/x',
          retracted_at: '2026-11-16T16:00:00Z',
          retraction_note: 'Superseded',
        },
      ],
      isPending: false,
      error: null,
    }
    m.retract.mockImplementation((_a: unknown, h: Handlers) => h.onSuccess?.({}))
    render(<BreakingPage />)
    const list = screen.getByRole('region', { name: /^published$/i })
    expect(within(list).getByText(item.headline)).toBeInTheDocument()
    expect(within(list).getByText(/by AdminTwo · Notified every phone/)).toBeInTheDocument()
    expect(within(list).getByText(/official statement/)).toBeInTheDocument()
    expect(within(list).getByText('Retracted')).toBeInTheDocument()
    expect(within(list).getByText(/superseded/i)).toBeInTheDocument()
    expect(within(list).getByText(/· Feed only/)).toBeInTheDocument()
    // Only the live item can be retracted.
    expect(within(list).getAllByRole('button', { name: /^retract$/i })).toHaveLength(1)

    await userEvent.click(within(list).getByRole('button', { name: /^retract$/i }))
    const confirm = screen.getByRole('group', { name: /confirm retraction/i })
    expect(within(confirm).getByText(/already delivered cannot be recalled/i)).toBeInTheDocument()
    expect(within(confirm).getByText(/publish a new item of kind other/i)).toBeInTheDocument()
    expect(m.retract).not.toHaveBeenCalled()
    const note = within(confirm).getByLabelText(/note/i)
    expect(note).toHaveFocus()
    await userEvent.type(note, 'Wrong person named')
    await userEvent.click(within(confirm).getByRole('button', { name: /retract item/i }))
    expect(m.retract.mock.calls[0][0]).toEqual({ id: 'b1', note: 'Wrong person named' })
  })

  it('says so when the server half is not deployed, and locks the form', () => {
    m.list = { data: undefined, isPending: false, error: new Error(NOT_DEPLOYED) }
    render(<BreakingPage />)
    expect(screen.getByText(/not switched on yet/i)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /review before publishing/i })).toBeDisabled()
    expect(screen.getByLabelText(/^headline$/i)).toBeDisabled()
  })

  it('has no accessibility violations, empty or in the confirm step', async () => {
    m.list = { data: [item], isPending: false, error: null }
    const { container } = render(<BreakingPage />)
    expect((await axe(container)).violations).toEqual([])
    await fill()
    await review()
    expect((await axe(container)).violations).toEqual([])
  })
})
