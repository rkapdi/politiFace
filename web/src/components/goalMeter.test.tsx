import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { GoalMeter } from './GoalMeter'
import { classPercentCorrect } from '../lib/liveOptions'

describe('GoalMeter', () => {
  it('states the class percent and the goal in text', () => {
    render(<GoalMeter goalPct={80} classPct={70} />)
    expect(screen.getByRole('region', { name: /class goal/i })).toBeInTheDocument()
    expect(screen.getByText('Class: 70% correct.')).toBeInTheDocument()
    expect(screen.getByText('Goal 80%.')).toBeInTheDocument()
  })

  it('says when the goal is met', () => {
    render(<GoalMeter goalPct={60} classPct={60} />)
    expect(screen.getByText('Class goal met: 60% correct.')).toBeInTheDocument()
  })

  it('handles a question nobody answered', () => {
    render(<GoalMeter goalPct={60} classPct={null} />)
    expect(screen.getByText('No answers on this one yet.')).toBeInTheDocument()
  })

  it('computes class percent from reveal counts', () => {
    expect(classPercentCorrect({ a: 1, b: 3 }, 'b')).toBe(75)
    expect(classPercentCorrect({}, 'b')).toBeNull()
    expect(classPercentCorrect({ a: 2 }, 'b')).toBe(0)
  })
})
