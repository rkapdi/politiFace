import { describe, expect, it, vi } from 'vitest'

const { rpcMock } = vi.hoisted(() => ({
  rpcMock: vi.fn(async () => ({ data: [{ ok: true }], error: null })),
}))
vi.mock('./supabase', () => ({
  supabase: { rpc: rpcMock },
}))

import { atRiskStudents, friendlyMessage } from './api'

describe('friendlyMessage', () => {
  it('maps known server messages to plain sentences', () => {
    expect(friendlyMessage({ message: 'this class reports aggregate data only' }))
      .toMatch(/aggregate/i)
    expect(friendlyMessage({ message: 'invalid or ended session code' }))
      .toMatch(/code/i)
  })

  it('hides unknown internals behind a generic sentence', () => {
    expect(friendlyMessage({ message: 'deadlock detected on relation xyz' }))
      .toBe('Something went wrong on our side. Try again.')
  })

  it('recognizes expired sessions and network failures', () => {
    expect(friendlyMessage({ message: 'JWT expired' })).toMatch(/sign in again/i)
    expect(friendlyMessage({ message: 'TypeError: Failed to fetch' })).toMatch(
      /offline/i,
    )
  })
})

describe('rpc fetchers', () => {
  it('calls the RPC with the exact server argument names', async () => {
    await atRiskStudents('c1', 0.6)
    expect(rpcMock).toHaveBeenCalledWith('at_risk_students', {
      p_cohort: 'c1',
      p_threshold: 0.6,
    })
  })

  it('throws the friendly message, never the raw one', async () => {
    rpcMock.mockResolvedValueOnce({
      data: null,
      error: { message: 'this class reports aggregate data only' },
    } as never)
    await expect(atRiskStudents('c1', 0.6)).rejects.toThrow(/aggregate/i)
  })
})
