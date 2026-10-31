import { describe, expect, it, vi } from 'vitest'

const { rpcMock, invokeMock, opsMock } = vi.hoisted(() => ({
  rpcMock: vi.fn(async () => ({ data: [{ ok: true }], error: null })),
  invokeMock: vi.fn(),
  opsMock: vi.fn(),
}))
vi.mock('./supabase', () => ({
  supabase: { rpc: rpcMock, functions: { invoke: invokeMock } },
}))
vi.mock('./opsLog', () => ({ logOpsEvent: opsMock }))

import { atRiskStudents, friendlyMessage, inviteLink, pushAnnouncement } from './api'

describe('friendlyMessage', () => {
  it('explains the course-identifier rule for class names and session titles', () => {
    for (const c of ['cohorts_name_no_course_id', 'live_sessions_title_no_course_id']) {
      expect(
        friendlyMessage({
          message: `new row for relation "x" violates check constraint "${c}"`,
        }),
      ).toMatch(/course codes, section and CRN numbers/i)
    }
  })

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

  it('flags hold-out questions reserved for a retention check', () => {
    expect(
      friendlyMessage({
        message:
          'question list contains 3 item(s) reserved for a scheduled retention check',
      }),
    ).toMatch(/retention check/i)
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

describe('inviteLink', () => {
  it('builds a hash-route welcome link on the current console URL', () => {
    expect(inviteLink('D7QMJA')).toBe(
      `${window.location.origin}${window.location.pathname}#/welcome?invite=D7QMJA`,
    )
  })
})

describe('pushAnnouncement', () => {
  it('asks class-announce to alert devices, and returns how many it reached', async () => {
    invokeMock.mockResolvedValueOnce({ data: { sent: 14 }, error: null })
    await expect(pushAnnouncement('a1')).resolves.toBe(14)
    expect(invokeMock).toHaveBeenCalledWith('class-announce', {
      body: { announcement_id: 'a1' },
    })
  })

  it('reports and logs a failed delivery instead of hiding it', async () => {
    opsMock.mockClear()
    invokeMock.mockResolvedValueOnce({
      data: null,
      error: { message: 'Failed to send a request to the Edge Function' },
    })
    await expect(pushAnnouncement('a1')).resolves.toBeNull()
    expect(opsMock).toHaveBeenCalledWith(
      'client_error',
      expect.objectContaining({ code: 'announce_push_failed' }),
    )
  })

  it('survives a thrown network error', async () => {
    invokeMock.mockRejectedValueOnce(new Error('offline'))
    await expect(pushAnnouncement('a1')).resolves.toBeNull()
  })
})

describe('announcement limits', () => {
  it('explains the rate limits rather than a generic failure', () => {
    expect(
      friendlyMessage({ message: 'too many messages this hour (5 max); try again shortly' }),
    ).toMatch(/5 messages this hour/)
    expect(
      friendlyMessage({ message: 'daily message limit reached for this class' }),
    ).toMatch(/20 messages for today/)
  })
})
