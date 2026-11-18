import { useState } from 'react'
import { Radio } from 'lucide-react'
import { useCohortRole, useCohortSessions } from '../lib/api'
import { toLocalInput, useSavedSessions, type SavedSession } from '../lib/liveDrafts'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card } from './ui'
import { EmptyState } from './EmptyState'
import { SkeletonTable } from './Skeleton'
import { QuestionPicker } from './QuestionPicker'
import { OwnQuestions } from './OwnQuestions'
import { SavedSessions } from './SavedSessions'

// The session draft lives in ClassView, not here: tab content unmounts on
// every tab switch, and a half-built session must survive a detour through
// Settings.
export type LiveDraft = {
  composing: boolean
  title: string
  seconds: number
  selected: Set<string>
  allowGuests: boolean
  // For a session saved for later: when the instructor means to run it,
  // as a datetime-local value ('' for no date). Only a label.
  plannedFor: string
  // The saved session being edited, or null when building a new one.
  draftId: string | null
  // Picker filters only: a question stays selected when filtered out of view.
  domainId: number | null
  mineOnly: boolean
}

export const emptyLiveDraft = (): LiveDraft => ({
  composing: false,
  title: '',
  seconds: 20,
  selected: new Set(),
  allowGuests: false,
  plannedFor: '',
  draftId: null,
  domainId: null,
  mineOnly: false,
})

export function LiveTab({
  cohortId,
  draft,
  onDraftChange,
}: {
  cohortId: string
  draft: LiveDraft
  onDraftChange: (draft: LiveDraft) => void
}) {
  const sessions = useCohortSessions(cohortId)
  // Null until the server has the saved-sessions functions; the tab then
  // works exactly as it did before them.
  const saved = useSavedSessions(cohortId)
  const canSave = saved.data != null
  // Shown after a save: how many of its questions are reserved right now.
  const [savedNotice, setSavedNotice] = useState<{ locked: number } | null>(null)
  const openHost = (sessionId: string) => {
    window.location.hash = `#/class/${cohortId}/live/${sessionId}`
  }
  const edit = (s: SavedSession) => {
    setSavedNotice(null)
    onDraftChange({
      ...emptyLiveDraft(),
      composing: true,
      title: s.title,
      seconds: s.question_seconds,
      selected: new Set(s.question_ids),
      allowGuests: s.allow_guests,
      plannedFor: toLocalInput(s.planned_for),
      draftId: s.id,
    })
  }
  // Authoring is faculty-only; TAs run sessions from the existing bank.
  const isFaculty = useCohortRole(cohortId).data === 'faculty'

  return (
    <div className="flex flex-col gap-3">
      <Card>
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-base font-bold text-ink">
            Run a live session
          </h2>
          {!draft.composing ? (
            <Button
              onClick={() => {
                setSavedNotice(null)
                onDraftChange({ ...draft, composing: true })
              }}
            >
              Set one up
            </Button>
          ) : (
            <Button
              variant="ghost"
              onClick={() =>
                // Leaving an edit drops it; a new half-built session is kept.
                onDraftChange(draft.draftId ? emptyLiveDraft() : { ...draft, composing: false })
              }
            >
              {S.common.cancel}
            </Button>
          )}
        </div>
        {draft.composing ? (
          <QuestionPicker
            cohortId={cohortId}
            draft={draft}
            onDraftChange={onDraftChange}
            canSave={canSave}
            onCreated={sessionId => {
              onDraftChange(emptyLiveDraft())
              openHost(sessionId)
            }}
            onSaved={locked => {
              onDraftChange(emptyLiveDraft())
              setSavedNotice({ locked })
            }}
          />
        ) : (
          <>
            {savedNotice ? (
              <div className="mb-3 flex max-w-xl flex-col gap-2">
                <Alert tone="success">{S.live.savedNotice}</Alert>
                {savedNotice.locked > 0 ? (
                  <Alert tone="info">{S.live.locked(savedNotice.locked)}</Alert>
                ) : null}
              </div>
            ) : null}
            <p className="max-w-xl text-sm text-ink-2">
              Students join from any browser with a code, no app needed. Answers
              grade server-side and feed the class analytics.
            </p>
          </>
        )}
      </Card>
      {saved.error ? <Alert tone="error">{saved.error.message}</Alert> : null}
      {saved.data ? (
        <SavedSessions
          cohortId={cohortId}
          sessions={saved.data}
          editingId={draft.composing ? draft.draftId : null}
          onEdit={edit}
          onStarted={openHost}
        />
      ) : null}
      {isFaculty ? (
        <OwnQuestions
          cohortId={cohortId}
          onRemoved={id => {
            if (!draft.selected.has(id)) return
            const selected = new Set(draft.selected)
            selected.delete(id)
            onDraftChange({ ...draft, selected })
          }}
        />
      ) : null}
      <Card>
        <h2 className="mb-3 text-base font-bold text-ink">
          Past sessions
        </h2>
        {sessions.isPending ? <SkeletonTable rows={3} /> : null}
        {sessions.error ? (
          <Alert tone="error">{sessions.error.message}</Alert>
        ) : null}
        {sessions.data && sessions.data.length === 0 ? (
          <EmptyState
            icon={Radio}
            title={S.empty.sessionsTitle}
            hint={S.empty.sessionsHint}
          />
        ) : null}
        {sessions.data && sessions.data.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <caption className="sr-only">Live sessions</caption>
              <thead>
                <tr className="border-b border-line text-left text-xs text-ink-3">
                  <th scope="col" className="py-2 pr-3 font-medium">Session</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Status</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Participants</th>
                  <th scope="col" className="py-2 font-medium">Avg correct</th>
                </tr>
              </thead>
              <tbody>
                {sessions.data.map(s => (
                  <tr key={s.session_id} className="border-b border-line last:border-b-0 hover:bg-raised">
                    <td className="py-3 pr-3">
                      <a
                        href={`#/class/${cohortId}/live/${s.session_id}`}
                        className="font-semibold text-ink hover:underline"
                      >
                        {s.title}
                      </a>
                    </td>
                    <td className="py-3 pr-3">
                      <Badge tone={s.status === 'ended' ? 'slate' : 'green'}>
                        {s.status}
                      </Badge>
                    </td>
                    <td className="py-3 pr-3 tabular-nums">{s.participants}</td>
                    <td className="py-3">
                      {Math.round(s.avg_correct * 100)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </Card>
    </div>
  )
}
