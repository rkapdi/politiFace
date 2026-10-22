import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const { setPolicy, addTa } = vi.hoisted(() => ({
  setPolicy: vi.fn(),
  addTa: vi.fn(),
}))

vi.mock('../lib/api', () => ({
  useReportingPolicy: () => ({
    data: {
      resolution: 'per_student',
      identity_display: 'roster',
      raw_retention_days: null,
      effective: 'per_student',
    },
    isPending: false,
    error: null,
  }),
  useSetReportingPolicy: () => ({
    mutate: setPolicy,
    isPending: false,
    isSuccess: false,
    error: null,
  }),
  useAddTa: () => ({ mutate: addTa, isPending: false, error: null }),
  useRemoveTa: () => ({ mutate: vi.fn(), isPending: false }),
  useAddCoFaculty: () => ({ mutate: vi.fn(), isPending: false, error: null }),
  useCohortTas: () => ({
    data: [{ user_id: 'u9', display: 'ta_person' }],
    isPending: false,
    error: null,
  }),
}))

import { SettingsTab } from './SettingsTab'

describe('SettingsTab', () => {
  it('saves a policy change and adds a TA by email', async () => {
    render(<SettingsTab cohortId="c1" />)
    expect(screen.getByText(/class-level statistics only/i)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('radio', { name: /aggregate only/i }))
    await userEvent.click(screen.getByRole('button', { name: /save reporting policy/i }))
    expect(setPolicy).toHaveBeenCalledWith(
      expect.objectContaining({ cohortId: 'c1', resolution: 'aggregate_only' }),
    )
    await userEvent.type(screen.getByLabelText(/ta email/i), 'ta@example.edu')
    await userEvent.click(screen.getByRole('button', { name: /add ta/i }))
    expect(addTa).toHaveBeenCalledWith({ cohortId: 'c1', email: 'ta@example.edu' })
    expect(screen.getByText('ta_person')).toBeInTheDocument()
  })
})
