import { useEffect, useRef, useState } from 'react'
import { CalendarClock, TriangleAlert } from 'lucide-react'
import { useDeleteSavedSession, useStartSavedSession, type SavedSession } from '../lib/liveDrafts'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card } from './ui'
import { EmptyState } from './EmptyState'

const when = (iso: string) =>
  new Date(iso).toLocaleString([], {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
  })

const small = '!px-3.5 !py-1.5 !text-[13px]'

function Row({
  cohortId,
  session: s,
  editing,
  onEdit,
  onStarted,
}: {
  cohortId: string
  session: SavedSession
  editing: boolean
  onEdit: () => void
  onStarted: (sessionId: string) => void
}) {
  const start = useStartSavedSession()
  const remove = useDeleteSavedSession()
  const [confirming, setConfirming] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // Focus follows the confirm step: onto Keep when it opens (the safe
  // choice), back to Delete when it closes.
  const focusNext = useRef<string | null>(null)
  useEffect(() => {
    if (!focusNext.current) return
    document.getElementById(focusNext.current)?.focus()
    focusNext.current = null
  })
  const locked = s.locked_now > 0
  const busy = start.isPending || remove.isPending
  const deleteId = `saved-delete-${s.id}`
  const keepId = `saved-keep-${s.id}`

  return (
    <li className="border-b border-line py-3.5 last:border-b-0">
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2.5">
        <div className="min-w-0 flex-1 basis-full sm:basis-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="break-words text-sm font-bold text-ink">{s.title}</span>
            {editing ? <Badge>{S.live.editingBadge}</Badge> : null}
          </div>
          <p className="mt-0.5 text-[13px] text-ink-2">
            {S.live.savedMeta(s.question_count, s.question_seconds)}
            {s.allow_guests ? `, ${S.live.guestsAllowed}` : ''}
          </p>
          <p className="mt-0.5 text-xs text-ink-3">
            {s.planned_for ? S.live.planned(when(s.planned_for)) : S.live.noDate}
            {s.created_by ? ` · ${S.live.savedBy(s.created_by)}` : ''}
          </p>
        </div>
        {confirming ? (
          <div
            role="group"
            aria-label={S.live.deleteGroup}
            className="flex flex-wrap items-center gap-2"
          >
            <span className="text-[13px] font-semibold text-ink">
              {S.live.deleteConfirm(s.title)}
            </span>
            <Button
              id={keepId}
              type="button"
              variant="ghost"
              className={small}
              onClick={() => {
                setConfirming(false)
                focusNext.current = deleteId
              }}
            >
              {S.live.deleteNo}
            </Button>
            <Button
              type="button"
              variant="danger"
              className={small}
              disabled={busy}
              onClick={() =>
                remove.mutate(
                  { cohortId, draftId: s.id },
                  {
                    onError: e => {
                      setError(e.message)
                      setConfirming(false)
                    },
                  },
                )
              }
            >
              {S.live.deleteYes}
            </Button>
          </div>
        ) : (
          <div
            role="group"
            aria-label={S.live.actionsFor(s.title)}
            className="flex flex-wrap items-center gap-2"
          >
            <Button
              type="button"
              className={small}
              disabled={locked || editing || busy}
              onClick={() => {
                setError(null)
                start.mutate(
                  { cohortId, draftId: s.id },
                  { onSuccess: d => onStarted(d.id), onError: e => setError(e.message) },
                )
              }}
            >
              {start.isPending ? S.live.starting : S.live.startSaved}
            </Button>
            <Button
              type="button"
              variant="ghost"
              className={small}
              disabled={busy}
              onClick={onEdit}
            >
              {S.live.editSaved}
            </Button>
            <Button
              id={deleteId}
              type="button"
              variant="ghost"
              className={small}
              disabled={busy}
              onClick={() => {
                setError(null)
                setConfirming(true)
                focusNext.current = keepId
              }}
            >
              {S.live.deleteSaved}
            </Button>
          </div>
        )}
      </div>
      {locked ? (
        <p className="mt-2.5 flex items-start gap-2 text-[13px] font-semibold text-ink">
          <TriangleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-risk" />
          {S.live.locked(s.locked_now)}
        </p>
      ) : null}
      {error ? (
        <div className="mt-2.5">
          <Alert tone="error">{error}</Alert>
        </div>
      ) : null}
    </li>
  )
}

/** Sessions prepared in advance: start, edit or delete each one. */
export function SavedSessions({
  cohortId,
  sessions,
  editingId,
  onEdit,
  onStarted,
}: {
  cohortId: string
  sessions: SavedSession[]
  editingId: string | null
  onEdit: (session: SavedSession) => void
  onStarted: (sessionId: string) => void
}) {
  return (
    <Card>
      <h2 className="text-base font-bold text-ink">{S.live.savedTitle}</h2>
      <p className="mb-3 mt-0.5 max-w-xl text-sm text-ink-2">{S.live.savedIntro}</p>
      {sessions.length === 0 ? (
        <EmptyState
          icon={CalendarClock}
          title={S.live.savedEmptyTitle}
          hint={S.live.savedEmptyHint}
        />
      ) : (
        <ul className="border-t border-line">
          {sessions.map(s => (
            <Row
              key={s.id}
              cohortId={cohortId}
              session={s}
              editing={editingId === s.id}
              onEdit={() => onEdit(s)}
              onStarted={onStarted}
            />
          ))}
        </ul>
      )}
    </Card>
  )
}
