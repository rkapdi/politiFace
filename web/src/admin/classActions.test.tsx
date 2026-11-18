import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'vitest-axe'

type Handlers = { onSuccess?: () => void }
const m = vi.hoisted(() => ({
  archive: vi.fn(),
  remove: vi.fn(),
  navigate: vi.fn(),
  error: null as Error | null,
}))
vi.mock('@tanstack/react-router', () => ({ useNavigate: () => m.navigate }))
vi.mock('./adminApi', () => ({
  useArchiveClass: () => ({ mutate: m.archive, reset: vi.fn(), isPending: false, error: m.error }),
  useDeleteClass: () => ({ mutate: m.remove, reset: vi.fn(), isPending: false, error: null }),
}))

import { ClassActions } from './ClassActions'

const facts = {
  cohort_id: 'c9',
  name: 'Section A',
  term: '2026F',
  join_code: 'ABC123',
  owner: 'prof_rivera',
  created_at: '2026-07-22T00:00:00Z',
  reporting_resolution: null,
  is_demo: false,
}
const archived = { ...facts, archived_at: '2026-11-18T14:00:00Z', archived_by: 'bright_quill_1321' }

beforeEach(() => {
  m.archive.mockReset()
  m.remove.mockReset()
  m.navigate.mockReset()
  m.error = null
})

describe('ClassActions', () => {
  it('asks before archiving, says nothing is deleted, and archives on confirm', async () => {
    render(<ClassActions facts={facts} />)
    expect(screen.queryByRole('button', { name: /delete permanently/i })).toBeNull()
    await userEvent.click(screen.getByRole('button', { name: /archive class/i }))
    const group = screen.getByRole('group', { name: /confirm archiving/i })
    expect(group).toHaveTextContent('Archive Section A?')
    expect(group).toHaveTextContent(/nothing is deleted/i)
    expect(screen.getByRole('button', { name: /^cancel$/i })).toHaveFocus()
    expect(m.archive).not.toHaveBeenCalled()
    await userEvent.click(screen.getByRole('button', { name: /^archive$/i }))
    expect(m.archive.mock.calls[0][0]).toEqual({ cohortId: 'c9', archive: true })
  })

  it('cancelling the archive step returns focus to the button', async () => {
    render(<ClassActions facts={facts} />)
    await userEvent.click(screen.getByRole('button', { name: /archive class/i }))
    await userEvent.click(screen.getByRole('button', { name: /^cancel$/i }))
    expect(screen.getByRole('button', { name: /archive class/i })).toHaveFocus()
  })

  it('an archived class says so and can be restored', async () => {
    render(<ClassActions facts={archived} />)
    expect(screen.getByText(/archived .* by bright_quill_1321/i)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /restore class/i }))
    expect(m.archive.mock.calls[0][0]).toEqual({ cohortId: 'c9', archive: false })
  })

  it('deletes permanently only after the exact name is typed', async () => {
    m.remove.mockImplementation((_a: unknown, h: Handlers) => h.onSuccess?.())
    render(<ClassActions facts={archived} />)
    await userEvent.click(screen.getByRole('button', { name: /delete permanently/i }))
    const form = screen.getByRole('form', { name: /delete permanently/i })
    expect(form).toHaveTextContent(/cannot be undone/i)
    const input = screen.getByLabelText(/type section a to confirm/i)
    expect(input).toHaveFocus()
    const submit = screen.getAllByRole('button', { name: /delete permanently/i }).at(-1)!
    expect(submit).toBeDisabled()
    await userEvent.type(input, 'section a')
    expect(submit).toBeDisabled()
    await userEvent.clear(input)
    await userEvent.type(input, 'Section A')
    expect(submit).toBeEnabled()
    await userEvent.click(submit)
    expect(m.remove.mock.calls[0][0]).toEqual({ cohortId: 'c9', confirmName: 'Section A' })
    expect(screen.getByRole('status')).toHaveTextContent('Section A was deleted permanently.')
    await userEvent.click(screen.getByRole('button', { name: /back to the console home/i }))
    expect(m.navigate).toHaveBeenCalledWith({ to: '/admin' })
  })

  it('shows a refusal from the server', () => {
    m.error = new Error('Archive the class before deleting it.')
    render(<ClassActions facts={facts} />)
    expect(screen.getByText('Archive the class before deleting it.')).toBeInTheDocument()
  })

  it('has no accessibility violations in either state', async () => {
    const { container, rerender } = render(<ClassActions facts={facts} />)
    expect((await axe(container)).violations).toEqual([])
    rerender(<ClassActions facts={archived} />)
    await userEvent.click(screen.getByRole('button', { name: /delete permanently/i }))
    expect((await axe(container)).violations).toEqual([])
  })
})
