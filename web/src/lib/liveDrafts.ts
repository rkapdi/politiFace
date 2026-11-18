// Saved live sessions: an instructor prepares a session in advance and
// starts it later. Four RPCs (save or edit, list, start, delete), all
// gated to TA or above of the class by the server. Students never see a
// saved session; there is nothing to join until it is started.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from './supabase'
import { friendlyMessage } from './api'

export type SavedSession = {
  id: string
  title: string
  question_ids: string[]
  question_count: number
  question_seconds: number
  allow_guests: boolean
  /** When the instructor means to run it. A label only: nothing starts by itself. */
  planned_for: string | null
  created_at: string
  updated_at: string
  /** The handle of whoever saved it. */
  created_by: string | null
  /** Questions reserved right now for a retention check. Above zero, it cannot start. */
  locked_now: number
  started_at: string | null
  started_session: string | null
}

type RpcError = { message: string; code?: string }

/** The server half is a separate deploy; before it lands the functions do not exist. */
const notDeployed = (e: RpcError) =>
  e.code === 'PGRST202' || /could not find the function/i.test(e.message)

async function call<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn as never, args as never)
  if (error) throw new Error(friendlyMessage(error))
  return data as T
}

/**
 * The class's saved sessions that have not been started, planned ones
 * first. Null means the server does not have the feature yet, and the
 * console then leaves it out instead of showing an error.
 */
export async function savedSessions(cohortId: string): Promise<SavedSession[] | null> {
  const { data, error } = await supabase.rpc(
    'live_session_drafts' as never,
    { p_cohort: cohortId } as never,
  )
  if (error) {
    if (notDeployed(error)) return null
    throw new Error(friendlyMessage(error))
  }
  return data as SavedSession[]
}

const key = (cohortId: string) => ['cohort', cohortId, 'saved-sessions']

export const useSavedSessions = (cohortId: string) =>
  useQuery({ queryKey: key(cohortId), queryFn: () => savedSessions(cohortId) })

// Every change refreshes the class's queries: starting one also adds a
// live session to the class's list.
function useSavedMutation<A extends { cohortId: string }, R>(fn: (a: A) => Promise<R>) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: fn,
    onSuccess: (_data, a) => void qc.invalidateQueries({ queryKey: ['cohort', a.cohortId] }),
  })
}

export const useSaveSession = () =>
  useSavedMutation(
    (a: {
      cohortId: string
      title: string
      questionIds: string[]
      questionSeconds: number
      allowGuests: boolean
      /** ISO time, or null for no date. */
      plannedFor: string | null
      /** Null saves a new one; an id replaces that saved session. */
      draftId: string | null
    }) =>
      call<{ id: string; question_count: number; locked_now: number }>('save_live_session_draft', {
        p_cohort: a.cohortId,
        p_title: a.title,
        p_question_ids: a.questionIds,
        p_question_seconds: a.questionSeconds,
        p_allow_guests: a.allowGuests,
        p_planned_for: a.plannedFor,
        p_draft: a.draftId,
      }),
  )

export const useStartSavedSession = () =>
  useSavedMutation((a: { cohortId: string; draftId: string }) =>
    call<{ id: string; join_code: string; question_count: number; draft_id: string }>(
      'start_live_session_draft',
      { p_draft: a.draftId },
    ),
  )

export const useDeleteSavedSession = () =>
  useSavedMutation((a: { cohortId: string; draftId: string }) =>
    call<void>('delete_live_session_draft', { p_draft: a.draftId }),
  )

/** An ISO time as the value of a datetime-local input, in the reader's zone. */
export function toLocalInput(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}

/** A datetime-local value as an ISO time; null when empty or not a date. */
export function fromLocalInput(value: string): string | null {
  if (!value) return null
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? null : d.toISOString()
}
