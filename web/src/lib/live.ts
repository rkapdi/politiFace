// Live-session client helpers shared by the faculty runner and the guest
// join page. Timing is server-anchored: the countdown derives from the
// row's question_started_at, never from a client-started timer.
import { useEffect, useRef, useState } from 'react'
import { supabase } from './supabase'
import { getLiveQuestion, type LiveQuestion } from './api'

export function secondsLeft(
  startedAtIso: string | null | undefined,
  questionSeconds: number,
  nowMs: number,
): number {
  if (!startedAtIso) return questionSeconds
  const elapsed = (nowMs - Date.parse(startedAtIso)) / 1000
  return Math.max(0, Math.min(questionSeconds, Math.round(questionSeconds - elapsed)))
}

// Phase state for a session: Realtime UPDATEs on the live_sessions row are
// the fast path; a 3-second poll is the fallback (Realtime can drop on
// campus wifi). Both funnel through the same server-authoritative RPC.
export function useLiveSession(sessionId: string) {
  const [state, setState] = useState<LiveQuestion | null>(null)
  const [error, setError] = useState<string | null>(null)
  const stateRef = useRef(state)
  stateRef.current = state

  useEffect(() => {
    let stopped = false
    const refresh = async () => {
      try {
        const next = await getLiveQuestion(sessionId)
        if (!stopped) {
          setState(next)
          setError(null)
        }
      } catch (e) {
        if (!stopped) setError((e as Error).message)
      }
    }
    void refresh()
    const channel = supabase
      .channel(`live:${sessionId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'live_sessions',
          filter: `id=eq.${sessionId}`,
        },
        () => void refresh(),
      )
      .subscribe()
    const interval = setInterval(() => {
      if (stateRef.current?.status !== 'ended') void refresh()
    }, 3000)
    return () => {
      stopped = true
      clearInterval(interval)
      void supabase.removeChannel(channel)
    }
  }, [sessionId])

  return { state, error }
}

// A ticking clock for countdowns; re-renders once a second.
export function useNow(): number {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 250)
    return () => clearInterval(t)
  }, [])
  return now
}
