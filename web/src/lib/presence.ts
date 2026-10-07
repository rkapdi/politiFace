// Presence (admin console): tells the founders' console this person has
// the web app open. Beats when signed in, then every 60 seconds while the
// tab is visible, and right away when the tab comes back into view.
// Fire-and-forget: failures are swallowed.
import { useEffect } from 'react'
import { supabase } from './supabase'

const BUILD = typeof __APP_BUILD__ === 'string' ? __APP_BUILD__ : 'web-dev'
export const PRESENCE_INTERVAL_MS = 60_000

function beat(): void {
  try {
    void Promise.resolve(
      supabase.rpc('heartbeat', { p_client: 'web', p_app_version: BUILD }),
    ).catch(() => undefined)
  } catch {
    // never let presence break the page
  }
}

const visible = () => document.visibilityState === 'visible'

/** Runs the heartbeat while `userId` is signed in. */
export function usePresence(userId: string | null | undefined): void {
  useEffect(() => {
    if (!userId) return
    if (visible()) beat()
    const timer = window.setInterval(() => {
      if (visible()) beat()
    }, PRESENCE_INTERVAL_MS)
    const onVisibility = () => {
      if (visible()) beat()
    }
    document.addEventListener('visibilitychange', onVisibility)
    return () => {
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [userId])
}
