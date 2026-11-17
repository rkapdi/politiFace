// The breaking desk's three admin-only RPCs: publish, retract and list.
// Unlike the rest of the console, errors keep the server's own message,
// because each one names the rule that was broken (see explain() in
// breaking.ts, which turns them into copy and a field).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { NOT_DEPLOYED, type BreakingKind } from './breaking'

async function call<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn as never, args as never)
  if (error) {
    const missing =
      (error as { code?: string }).code === 'PGRST202' ||
      /could not find the function/i.test(error.message)
    throw new Error(missing ? NOT_DEPLOYED : error.message)
  }
  return data as T
}

export type BreakingItem = {
  id: string
  kind: BreakingKind
  headline: string
  detail: string | null
  source_url: string
  source_is_official: boolean
  second_source_url: string | null
  notify: boolean
  published_at: string
  /** The publishing admin's handle. */
  published_by: string | null
  retracted_at: string | null
  retraction_note: string | null
}

export type BreakingPublished = {
  id: string
  published_at: string
  notify: boolean
  /** The alert was asked for straight away; otherwise it waits for the next poll. */
  kicked: boolean
  /** The same headline went out in the last 10 minutes, so nothing new happened. */
  duplicate: boolean
}

export type PublishArgs = {
  kind: BreakingKind
  headline: string
  detail: string
  source: string
  official: boolean
  second: string
  notify: boolean
}

// No retry anywhere here: a list that fails should say so at once, and a
// publish must never be sent twice on the console's own initiative.
export const useBreakingList = () =>
  useQuery({
    queryKey: ['admin', 'breaking'],
    queryFn: () => call<BreakingItem[]>('admin_breaking_list'),
    retry: false,
  })

export const usePublishBreaking = () => {
  const qc = useQueryClient()
  return useMutation({
    retry: false,
    mutationFn: (a: PublishArgs) =>
      call<BreakingPublished>('admin_publish_breaking', {
        p_kind: a.kind,
        p_headline: a.headline.trim(),
        p_source_url: a.source.trim(),
        p_detail: a.detail.trim() || null,
        p_second_source_url: a.second.trim() || null,
        p_source_is_official: a.official,
        p_notify: a.notify,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['admin', 'breaking'] })
      void qc.invalidateQueries({ queryKey: ['admin', 'audit'] })
    },
  })
}

export const useRetractBreaking = () => {
  const qc = useQueryClient()
  return useMutation({
    retry: false,
    mutationFn: (a: { id: string; note: string }) =>
      call<{ id: string; retracted_at: string }>('admin_retract_breaking', {
        p_id: a.id,
        p_note: a.note.trim() || null,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['admin', 'breaking'] })
      void qc.invalidateQueries({ queryKey: ['admin', 'audit'] })
    },
  })
}
