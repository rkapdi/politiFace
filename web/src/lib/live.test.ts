import { describe, expect, it } from 'vitest'
import { secondsLeft } from './live'

describe('secondsLeft', () => {
  it('counts down from the server timestamp', () => {
    expect(
      secondsLeft('2026-08-21T00:00:00Z', 20, Date.parse('2026-08-21T00:00:07Z')),
    ).toBe(13)
  })

  it('never goes negative', () => {
    expect(
      secondsLeft('2026-08-21T00:00:00Z', 20, Date.parse('2026-08-21T00:01:00Z')),
    ).toBe(0)
  })

  it('is full when the question has not started', () => {
    expect(secondsLeft(null, 20, Date.parse('2026-08-21T00:00:00Z'))).toBe(20)
  })
})
