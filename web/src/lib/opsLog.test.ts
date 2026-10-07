import { beforeEach, describe, expect, it, vi } from 'vitest'

const rpc = vi.hoisted(() => vi.fn(async () => ({ error: null })))
vi.mock('./supabase', () => ({ supabase: { rpc } }))

import { logOpsEvent } from './opsLog'

describe('logOpsEvent', () => {
  beforeEach(() => rpc.mockClear())

  it('sends kind, client web, build, and the details', async () => {
    logOpsEvent('signin_send_failed', {
      code: '429',
      detail: { status: 429 },
      email: 'maria@mymdc.net',
    })
    await Promise.resolve()
    expect(rpc).toHaveBeenCalledWith('log_ops_event', {
      p_kind: 'signin_send_failed',
      p_client: 'web',
      p_code: '429',
      p_detail: { status: 429 },
      p_app_version: expect.stringMatching(/^web-/),
      p_email: 'maria@mymdc.net',
    })
  })

  it('never throws, even when the call fails', async () => {
    rpc.mockRejectedValueOnce(new Error('offline'))
    expect(() => logOpsEvent('client_error', { code: 'x' })).not.toThrow()
    await Promise.resolve()
  })
})
