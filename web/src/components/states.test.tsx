import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Users } from 'lucide-react'
import { EmptyState } from './EmptyState'
import { SkeletonStats, SkeletonTable } from './Skeleton'

describe('EmptyState', () => {
  it('renders icon, title, hint, and a working action', async () => {
    const act = vi.fn()
    render(
      <EmptyState
        icon={Users}
        title="No students yet"
        hint="Share the class join code and students appear here as they enroll."
        actionLabel="Copy join code"
        onAction={act}
      />,
    )
    expect(screen.getByText('No students yet')).toBeInTheDocument()
    expect(screen.getByText(/share the class join code/i)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /copy join code/i }))
    expect(act).toHaveBeenCalled()
  })

  it('renders without an action when none applies', () => {
    render(<EmptyState icon={Users} title="No sessions" hint="Run one." />)
    expect(screen.queryByRole('button')).toBeNull()
  })
})

describe('Skeletons', () => {
  it('are marked busy and carry no readable text', () => {
    const { container } = render(
      <>
        <SkeletonStats count={4} />
        <SkeletonTable rows={5} />
      </>,
    )
    expect(screen.getAllByRole('status').length).toBe(2)
    expect(container.textContent?.replace(/Loading/g, '').trim()).toBe('')
  })
})
