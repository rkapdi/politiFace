import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { renderHook } from '@testing-library/react'

const rpc = vi.hoisted(() => vi.fn(async () => ({ error: null })))
vi.mock('./supabase', () => ({ supabase: { rpc } }))

import { PRESENCE_INTERVAL_MS, usePresence } from './presence'

let visibility: DocumentVisibilityState = 'visible'

describe('usePresence', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    rpc.mockClear()
    visibility = 'visible'
    vi.spyOn(document, 'visibilityState', 'get').mockImplementation(() => visibility)
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it('does nothing when signed out', () => {
    renderHook(() => usePresence(null))
    vi.advanceTimersByTime(PRESENCE_INTERVAL_MS * 3)
    expect(rpc).not.toHaveBeenCalled()
  })

  it('beats on sign-in and every interval while visible, as the web client', () => {
    renderHook(() => usePresence('u1'))
    expect(rpc).toHaveBeenCalledTimes(1)
    expect(rpc).toHaveBeenCalledWith('heartbeat', {
      p_client: 'web',
      p_app_version: expect.stringMatching(/^web-/),
    })
    vi.advanceTimersByTime(PRESENCE_INTERVAL_MS)
    expect(rpc).toHaveBeenCalledTimes(2)
  })

  it('skips hidden tabs and beats again when the tab returns', () => {
    renderHook(() => usePresence('u1'))
    visibility = 'hidden'
    vi.advanceTimersByTime(PRESENCE_INTERVAL_MS * 3)
    expect(rpc).toHaveBeenCalledTimes(1)
    visibility = 'visible'
    document.dispatchEvent(new Event('visibilitychange'))
    expect(rpc).toHaveBeenCalledTimes(2)
  })

  it('stops when unmounted (signed out)', () => {
    const { unmount } = renderHook(() => usePresence('u1'))
    unmount()
    vi.advanceTimersByTime(PRESENCE_INTERVAL_MS * 3)
    expect(rpc).toHaveBeenCalledTimes(1)
  })
})
