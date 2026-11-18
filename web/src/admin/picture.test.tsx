import { describe, expect, it } from 'vitest'
import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'
import type { AdminPicture, AuditRow } from './adminApi'
import { Picture } from './Picture'

const days: AdminPicture['days'] = Array.from({ length: 14 }, (_, i) => ({
  day: `2026-11-${String(i + 5).padStart(2, '0')}`,
  answers: i === 13 ? 19 : i === 2 ? 4 : 0,
  practising: i === 13 ? 1 : i === 2 ? 2 : 0,
  live_sessions: i === 6 ? 1 : 0,
  actions: i === 13 ? 4 : 0,
  students: i >= 12 ? 21 : null,
  on_track: i >= 12 ? 0 : null,
}))
const picture: AdminPicture = {
  tz: 'America/Toronto',
  now: { students: 21, on_track: 0, practised_7d: 2, live_7d: 0 },
  classes: [],
  days,
  questions: [],
}
const audit = (action: string, at: string): AuditRow => ({
  id: Math.floor(Math.random() * 1e6),
  created_at: at,
  actor_handle: 'bright_quill_1321',
  action,
  target_user: null,
  target_label: null,
  target_cohort: null,
  target_session: null,
  details: {},
})
const rows = [
  audit('class_archived', '2026-11-18T15:12:51Z'),
  audit('class_archived', '2026-11-18T15:12:51Z'),
  audit('class_archived', '2026-11-18T15:12:51Z'),
  audit('faculty_granted', '2026-11-18T16:00:00Z'),
  // Not actions: never named.
  audit('console_open', '2026-11-18T16:01:00Z'),
]

const cell = (container: HTMLElement, lane: string, day: number) =>
  container.querySelector(`[data-lane="${lane}"][data-day="${day}"]`) as HTMLElement

describe('operating picture day summaries', () => {
  it('shows nothing until a day is pointed at', () => {
    render(<Picture picture={picture} audit={rows} />)
    expect(screen.queryByRole('tooltip')).toBeNull()
  })

  it('summarises a day across every lane, with what the hovered lane counts', async () => {
    const { container } = render(<Picture picture={picture} audit={rows} />)
    await userEvent.hover(cell(container, 'answers', 13))
    const tip = screen.getByRole('tooltip')
    expect(tip).toHaveTextContent(/^Today, Wed, Nov 18/)
    expect(tip).toHaveTextContent('19 answers from 1 student')
    expect(tip).toHaveTextContent('No live session started')
    expect(tip).toHaveTextContent('0%, 0 of 21 students above the pass line')
    expect(tip).toHaveTextContent('4 staff actions: 3 classes archived, 1 instructor approved')
    expect(tip).not.toHaveTextContent(/console/i)
    expect(tip).toHaveTextContent(/practice and review answers by students in real classes/i)
  })

  it('explains the lane under the pointer', async () => {
    const { container } = render(<Picture picture={picture} audit={rows} />)
    await userEvent.hover(cell(container, 'onTrack', 4))
    const tip = screen.getByRole('tooltip')
    expect(tip).toHaveTextContent('No snapshot that day')
    expect(tip).toHaveTextContent(/projected at 48 of 80 or more/i)
    await userEvent.hover(cell(container, 'live', 6))
    expect(screen.getByRole('tooltip')).toHaveTextContent('1 live session started')
    expect(screen.getByRole('tooltip')).toHaveTextContent(/live sessions instructors started/i)
  })

  it('says so on a quiet day, and leaves when the pointer leaves', async () => {
    const { container } = render(<Picture picture={picture} audit={rows} />)
    await userEvent.hover(cell(container, 'actions', 0))
    const tip = screen.getByRole('tooltip')
    expect(tip).toHaveTextContent('No practice answers')
    expect(tip).toHaveTextContent('No staff actions')
    await userEvent.unhover(screen.getByRole('group'))
    expect(screen.queryByRole('tooltip')).toBeNull()
  })

  it('a tap shows the day too', async () => {
    const { container } = render(<Picture picture={picture} audit={rows} />)
    fireEvent.click(cell(container, 'answers', 2))
    expect(screen.getByRole('tooltip')).toHaveTextContent('4 answers from 2 students')
  })

  it('can be read with the keyboard, and is announced', async () => {
    render(<Picture picture={picture} audit={rows} />)
    await userEvent.tab()
    const group = screen.getByRole('group', { name: /arrow keys/i })
    expect(group).toHaveFocus()
    // Focus starts on today.
    expect(screen.getByRole('tooltip')).toHaveTextContent(/^Today/)
    await userEvent.keyboard('{ArrowLeft}')
    expect(screen.getByRole('tooltip')).toHaveTextContent(/^Tue, Nov 17/)
    await userEvent.keyboard('{Home}')
    expect(screen.getByRole('tooltip')).toHaveTextContent(/^Thu, Nov 5/)
    await userEvent.keyboard('{ArrowDown}{ArrowDown}')
    expect(within(screen.getByRole('tooltip')).getByText(/projected at 48 of 80/i)).toBeInTheDocument()
    expect(document.getElementById('picture-day')).toHaveTextContent(/^Thu, Nov 5\. Answers: No practice answers\./)
    await userEvent.keyboard('{Escape}')
    expect(screen.queryByRole('tooltip')).toBeNull()
  })

  it('works without the audit log, counting actions only', async () => {
    const { container } = render(<Picture picture={picture} />)
    await userEvent.hover(cell(container, 'actions', 13))
    expect(screen.getByRole('tooltip')).toHaveTextContent(/4 staff actions(?!:)/)
  })

  it('has no accessibility violations with a summary open', async () => {
    const { container } = render(<Picture picture={picture} audit={rows} />)
    await userEvent.hover(cell(container, 'answers', 13))
    expect((await axe(container)).violations).toEqual([])
  })
})
