import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { axe } from 'vitest-axe'
import type { DeletionBlocker } from '../lib/api'

const updateMutate = vi.fn()
const deleteMutate = vi.fn()
const transferMutate = vi.fn()
let blockersData: DeletionBlocker[] = []

vi.mock('../auth/SessionProvider', () => ({
  useSession: () => ({
    session: { user: { id: 'u1', email: 'purcell@mdc.edu' } },
    loading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      updateUser: vi.fn(async () => ({ error: null })),
      signOut: vi.fn(async () => ({ error: null })),
    },
  },
}))

vi.mock('../lib/api', () => ({
  useMyProfile: () => ({
    data: { handle: 'prof_purcell', school: 'Miami Dade College' },
    isPending: false,
    error: null,
  }),
  useUpdateMyProfile: () => ({
    mutate: updateMutate,
    isPending: false,
    error: null,
  }),
  useDeletionBlockers: () => ({
    data: blockersData,
    isPending: false,
    error: null,
  }),
  useCohortCoFaculty: () => ({
    data: [{ user_id: 'u2', display: 'co_teach' }],
    isPending: false,
    error: null,
  }),
  useTransferOwnership: () => ({
    mutate: transferMutate,
    isPending: false,
    error: null,
  }),
  useDeleteAccount: () => ({
    mutate: deleteMutate,
    isPending: false,
    error: null,
  }),
}))

import { AccountPage } from './AccountPage'

describe('AccountPage', () => {
  beforeEach(() => {
    blockersData = []
    vi.clearAllMocks()
  })

  it('renders profile fields and saves edits through the RPC', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    render(<AccountPage />)
    const handle = screen.getByLabelText(/display name/i)
    expect(handle).toHaveValue('prof_purcell')
    expect(screen.getByText(/purcell@mdc\.edu/)).toBeInTheDocument()
    await userEvent.clear(handle)
    await userEvent.type(handle, 'purcell_pols')
    await userEvent.click(screen.getByRole('button', { name: /^save$/i }))
    expect(updateMutate).toHaveBeenCalledWith(
      { handle: 'purcell_pols', school: 'Miami Dade College' },
      expect.anything(),
    )
  })

  it('gates deletion behind a typed confirmation', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    render(<AccountPage />)
    await userEvent.click(
      screen.getByRole('button', { name: /delete account/i }),
    )
    const confirmButton = screen
      .getAllByRole('button', { name: /delete account/i })
      .at(-1)!
    expect(confirmButton).toBeDisabled()
    await userEvent.type(screen.getByLabelText(/type delete/i), 'DELETE')
    expect(confirmButton).toBeEnabled()
    await userEvent.click(confirmButton)
    expect(deleteMutate).toHaveBeenCalled()
  })

  it('blocks deletion while owned classes have members and offers transfer', async () => {
    const { default: userEvent } = await import('@testing-library/user-event')
    blockersData = [{ cohort_id: 'c1', name: 'POS2041 Fall', others: 31 }]
    render(<AccountPage />)
    expect(
      screen.queryByRole('button', { name: /delete account/i }),
    ).toBeNull()
    expect(screen.getByText(/cannot be deleted yet/i)).toBeInTheDocument()
    expect(screen.getByText('POS2041 Fall')).toBeInTheDocument()
    await userEvent.selectOptions(screen.getByLabelText(/new owner/i), 'u2')
    await userEvent.click(
      screen.getByRole('button', { name: /transfer ownership/i }),
    )
    expect(transferMutate).toHaveBeenCalledWith({
      cohortId: 'c1',
      newOwner: 'u2',
    })
  })

  it('has no axe violations', async () => {
    const { container } = render(<AccountPage />)
    const results = await axe(container)
    expect(results.violations).toEqual([])
  })
})
