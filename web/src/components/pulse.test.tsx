import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { CohortPulse } from '../lib/api'
import { PulseBanner } from './PulseBanner'
import { DistributionChart } from './DistributionChart'

const pulse: CohortPulse = {
  students: 32,
  active_7d: 12,
  above_line: 18,
  at_risk: 14,
  model_version: 'v2-shrunk-w45d-cap50-p12@0.40',
  sentence:
    '18 of 32 students project above the pass line. U.S. Constitution is the weakest domain at 46%. 12 of 32 practiced this week.',
  cards: [
    {
      kind: 'at_risk',
      headline: '14 students project below the pass line',
      detail: 'The Students tab ranks them lowest readiness first.',
    },
    {
      kind: 'weak_domain',
      headline: 'U.S. Constitution is dragging the class',
      detail: 'Average readiness 46%. A live reteach session moves this fastest.',
    },
  ],
}

describe('PulseBanner', () => {
  it('leads with the sentence and routes card actions', async () => {
    const onAction = vi.fn()
    render(<PulseBanner pulse={pulse} onAction={onAction} />)
    expect(
      screen.getByText(/18 of 32 students project above the pass line/),
    ).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /see who/i }))
    expect(onAction).toHaveBeenCalledWith('at_risk')
    await userEvent.click(
      screen.getByRole('button', { name: /run a reteach session/i }),
    )
    expect(onAction).toHaveBeenCalledWith('weak_domain')
  })

  it('renders the below-floor state without statistics', () => {
    render(
      <PulseBanner
        pulse={{
          below_floor: true,
          students: 3,
          sentence: 'Class statistics appear once 5 students join. 3 joined so far.',
          cards: [],
        }}
        onAction={() => {}}
      />,
    )
    expect(screen.getByText(/once 5 students join/i)).toBeInTheDocument()
    expect(screen.queryByRole('button')).toBeNull()
  })
})

describe('DistributionChart', () => {
  it('renders every bin with counts and names the pass line', () => {
    render(
      <DistributionChart
        distribution={{
          students: 32,
          bins: { '30-39': 4, '40-49': 10, '50-59': 12, '60-69': 6 },
          avg: 49.5,
          above_line: 18,
          pass_line: 48,
        }}
      />,
    )
    expect(screen.getByText(/pass line 48/i)).toBeInTheDocument()
    // The sr-only table carries all eight bins, zeros included.
    const rows = screen.getAllByRole('row')
    expect(rows.length).toBe(9) // header + 8 bins
    expect(screen.getByRole('cell', { name: '12' })).toBeInTheDocument()
  })
})
