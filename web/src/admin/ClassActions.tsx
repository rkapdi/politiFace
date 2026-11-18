import { useEffect, useRef, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { useArchiveClass, useDeleteClass, type ClassRecord } from './adminApi'
import { A } from './strings'

const btn =
  'rounded-full px-3 py-1.5 text-xs font-bold disabled:cursor-not-allowed disabled:opacity-50'
const ghost = `${btn} bg-control text-ink hover:bg-line-strong`
const danger = `${btn} text-risk ring-[1.5px] ring-inset ring-risk hover:bg-control`

const day = (iso: string) =>
  new Date(iso).toLocaleDateString([], { day: 'numeric', month: 'short', year: 'numeric' })

/**
 * Archive or restore a class, and delete an archived one permanently.
 * Archiving is reversible and deletes nothing; deleting needs the exact
 * class name typed in. The server enforces both rules as well.
 */
export function ClassActions({ facts }: { facts: ClassRecord['facts'] }) {
  const archive = useArchiveClass()
  const remove = useDeleteClass()
  const navigate = useNavigate()
  const [step, setStep] = useState<'idle' | 'archive' | 'delete'>('idle')
  const [typed, setTyped] = useState('')
  const [deletedName, setDeletedName] = useState<string | null>(null)
  // Focus follows each step: into it when it opens, back to its opener when it closes.
  const focusNext = useRef<string | null>(null)
  useEffect(() => {
    if (!focusNext.current) return
    document.getElementById(focusNext.current)?.focus()
    focusNext.current = null
  })

  const archived = facts.archived_at != null
  const error = archive.error ?? remove.error
  const busy = archive.isPending || remove.isPending
  const open = (s: 'archive' | 'delete', focus: string) => {
    archive.reset()
    remove.reset()
    setTyped('')
    setStep(s)
    focusNext.current = focus
  }
  const close = (focus: string) => {
    setStep('idle')
    focusNext.current = focus
  }

  if (deletedName) {
    return (
      <div role="status" className="mt-1">
        <p className="admin-strong">{A.klass.deleted(deletedName)}</p>
        <button
          type="button"
          className={`${ghost} mt-2`}
          onClick={() => void navigate({ to: '/admin' })}
        >
          {A.klass.backHome}
        </button>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-2">
      {archived ? (
        <>
          <p className="text-[12.5px] leading-[18px] text-ink-2">
            {A.klass.archivedNote(day(facts.archived_at!), facts.archived_by ?? null)}
          </p>
          <div className="flex flex-wrap gap-2">
            <button
              id="class-restore"
              type="button"
              className={ghost}
              disabled={busy}
              onClick={() => {
                setStep('idle')
                archive.mutate({ cohortId: facts.cohort_id, archive: false })
              }}
            >
              {A.klass.restore}
            </button>
            {step !== 'delete' ? (
              <button
                id="class-delete"
                type="button"
                className={danger}
                disabled={busy}
                onClick={() => open('delete', 'class-delete-name')}
              >
                {A.klass.deleteTitle}
              </button>
            ) : null}
          </div>
          {step === 'delete' ? (
            <form
              aria-label={A.klass.deleteTitle}
              className="rounded-lg bg-raised p-3 ring-[1.5px] ring-inset ring-risk-line"
              onSubmit={e => {
                e.preventDefault()
                remove.mutate(
                  { cohortId: facts.cohort_id, confirmName: typed },
                  { onSuccess: () => setDeletedName(facts.name) },
                )
              }}
            >
              <p className="admin-strong text-[13px]">{A.klass.deleteTitle}</p>
              <p id="class-delete-warn" className="mt-1 text-[12.5px] leading-[18px] text-ink-2">
                {A.klass.deleteBody}
              </p>
              <label htmlFor="class-delete-name" className="mt-2 block text-xs font-bold text-ink">
                {A.klass.deleteLabel(facts.name)}
              </label>
              <input
                id="class-delete-name"
                value={typed}
                autoComplete="off"
                onChange={e => setTyped(e.target.value)}
                aria-describedby="class-delete-warn"
                className="mt-1 w-full rounded-md border px-2 py-1"
              />
              <div className="mt-2 flex flex-wrap gap-2">
                <button
                  type="button"
                  className={ghost}
                  disabled={busy}
                  onClick={() => close('class-delete')}
                >
                  {A.klass.cancel}
                </button>
                <button
                  type="submit"
                  className={danger}
                  disabled={busy || typed.trim() !== facts.name}
                >
                  {remove.isPending ? A.klass.deleting : A.klass.deleteYes}
                </button>
              </div>
            </form>
          ) : null}
        </>
      ) : step === 'archive' ? (
        <div role="group" aria-label={A.klass.archiveGroup} className="rounded-lg bg-raised p-3">
          <p className="admin-strong text-[13px]">{A.klass.archiveConfirm(facts.name)}</p>
          <p className="mt-1 text-[12.5px] leading-[18px] text-ink-2">{A.klass.archiveHint}</p>
          <div className="mt-2 flex flex-wrap gap-2">
            <button
              id="class-archive-cancel"
              type="button"
              className={ghost}
              disabled={busy}
              onClick={() => close('class-archive')}
            >
              {A.klass.cancel}
            </button>
            <button
              type="button"
              className={`${btn} bg-cta text-on-cta hover:brightness-95`}
              disabled={busy}
              onClick={() =>
                archive.mutate(
                  { cohortId: facts.cohort_id, archive: true },
                  {
                    onSuccess: () => {
                      setStep('idle')
                      focusNext.current = 'class-restore'
                    },
                  },
                )
              }
            >
              {A.klass.archiveYes}
            </button>
          </div>
        </div>
      ) : (
        <div>
          <button
            id="class-archive"
            type="button"
            className={ghost}
            disabled={busy}
            onClick={() => open('archive', 'class-archive-cancel')}
          >
            {A.klass.archive}
          </button>
          <p className="mt-1 text-[12px] leading-[17px] text-ink-3">{A.klass.archiveHint}</p>
        </div>
      )}
      {error ? <p className="sev-fail text-[12.5px]">{error.message}</p> : null}
    </div>
  )
}
