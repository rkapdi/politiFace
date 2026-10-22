// Problem log (admin console 2a): fire-and-forget reports of what went
// wrong for a user, so the founders can see it on the person's timeline.
// Never blocks or breaks a flow; failures to log are swallowed.
import { supabase } from './supabase'

export type OpsKind =
  | 'signin_send_failed'
  | 'signin_verify_failed'
  | 'join_refused'
  | 'client_error'
  | 'app_seen'

const BUILD = typeof __APP_BUILD__ === 'string' ? __APP_BUILD__ : 'web-dev'

export function logOpsEvent(
  kind: OpsKind,
  opts: { code?: string; detail?: Record<string, unknown>; email?: string } = {},
): void {
  try {
    void Promise.resolve(
      supabase.rpc('log_ops_event' as never, {
        p_kind: kind,
        p_client: 'web',
        p_code: opts.code ?? null,
        p_detail: opts.detail ?? null,
        p_app_version: BUILD,
        p_email: opts.email ?? null,
      } as never),
    ).catch(() => undefined)
  } catch {
    // never let logging break the caller
  }
}
