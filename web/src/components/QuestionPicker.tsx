import { useMemo, type FormEvent } from 'react'
import {
  useCreateLiveSession,
  useDomains,
  usePickableQuestions,
} from '../lib/api'
import { Alert, Badge, Button, Spinner, fieldClass } from './ui'
import type { LiveDraft } from './LiveTab'
import { S } from '../lib/strings'

// create_live_session refuses more than this.
const MAX_QUESTIONS = 50

export function QuestionPicker({
  cohortId,
  draft,
  onDraftChange,
  onCreated,
}: {
  cohortId: string
  draft: LiveDraft
  onDraftChange: (draft: LiveDraft) => void
  onCreated: (sessionId: string) => void
}) {
  const questions = usePickableQuestions(cohortId)
  const domains = useDomains()
  const create = useCreateLiveSession()
  const { title, seconds, selected, allowGuests, domainId, mineOnly } = draft

  const byDomain = useMemo(() => {
    const groups = new Map<number, typeof questions.data>()
    for (const q of questions.data ?? []) {
      if (domainId !== null && q.domain_id !== domainId) continue
      if (mineOnly && !q.cohort_id) continue
      const list = groups.get(q.domain_id) ?? []
      list.push(q)
      groups.set(q.domain_id, list)
    }
    return groups
  }, [questions.data, domainId, mineOnly])

  if (questions.isPending || domains.isPending) {
    return <Spinner label="Loading question bank" />
  }
  if (questions.error) {
    return <Alert tone="error">{questions.error.message}</Alert>
  }

  const toggle = (id: string) => {
    const next = new Set(selected)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    onDraftChange({ ...draft, selected: next })
  }

  const submit = (e: FormEvent) => {
    e.preventDefault()
    create.mutate(
      {
        cohortId,
        title: title.trim(),
        questionIds: [...selected],
        questionSeconds: seconds,
        allowGuests,
      },
      { onSuccess: data => onCreated((data as { id: string }).id) },
    )
  }

  const label = 'flex flex-col gap-1.5 text-[13px] font-semibold text-ink-2'
  const check = 'flex cursor-pointer items-center gap-2.5 text-sm font-medium text-ink'

  // Two columns: the question bank on the left, the session being built on
  // the right. On a phone the session panel comes first.
  return (
    <form onSubmit={submit} className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
      <div className="flex flex-col gap-3.5 rounded-lg bg-raised p-4 lg:sticky lg:top-3 lg:col-start-2 lg:row-start-1">
        <label className={label}>
          Session title
          <input
            required
            minLength={3}
            maxLength={80}
            value={title}
            onChange={e => onDraftChange({ ...draft, title: e.target.value })}
            className={fieldClass}
          />
        </label>
        <label className={label}>
          Seconds per question
          <select
            value={seconds}
            onChange={e =>
              onDraftChange({ ...draft, seconds: Number(e.target.value) })
            }
            className={fieldClass}
          >
            {[10, 15, 20, 30, 45, 60].map(s => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        </label>
        <label className={check}>
          <input
            type="checkbox"
            checked={allowGuests}
            onChange={e => onDraftChange({ ...draft, allowGuests: e.target.checked })}
            className="size-4 accent-cta"
          />
          {S.live.allowGuests}
        </label>
        <div className="flex items-center justify-between gap-3 border-t border-line-strong pt-3.5">
          <Badge tone={selected.size > 0 ? 'green' : 'slate'}>
            {selected.size} selected
          </Badge>
          <Button
            type="submit"
            disabled={selected.size === 0 || selected.size > MAX_QUESTIONS || create.isPending}
          >
            Start session
          </Button>
        </div>
        {selected.size > MAX_QUESTIONS ? (
          <Alert tone="info">{S.live.tooMany}</Alert>
        ) : null}
        {create.error ? <Alert tone="error">{create.error.message}</Alert> : null}
      </div>

      <div className="flex min-w-0 flex-col gap-3 lg:col-start-1 lg:row-start-1">
        <div className="flex flex-wrap items-end gap-x-5 gap-y-3">
          <label className={label}>
            {S.live.filterDomain}
            <select
              value={domainId ?? ''}
              onChange={e =>
                onDraftChange({
                  ...draft,
                  domainId: e.target.value === '' ? null : Number(e.target.value),
                })
              }
              className={fieldClass}
            >
              <option value="">{S.live.allDomains}</option>
              {(domains.data ?? []).map(d => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </select>
          </label>
          <label className={`${check} pb-2.5`}>
            <input
              type="checkbox"
              checked={mineOnly}
              onChange={e => onDraftChange({ ...draft, mineOnly: e.target.checked })}
              className="size-4 accent-cta"
            />
            {S.live.mineOnly}
          </label>
        </div>
        <div className="max-h-[32rem] overflow-y-auto rounded-lg bg-raised">
          {byDomain.size === 0 ? (
            <p className="p-4 text-sm text-ink-3">{S.live.noMatches}</p>
          ) : null}
          {[...byDomain.entries()].map(([groupId, qs]) => (
            <fieldset key={groupId} className="border-b border-line-strong p-3 last:border-b-0">
              <legend className="px-2 text-xs font-bold text-ink-2">
                {domains.data?.find(d => d.id === groupId)?.name ??
                  `Domain ${groupId}`}
              </legend>
              <ul className="flex flex-col gap-0.5">
                {(qs ?? []).map(q => (
                  <li key={q.id}>
                    <label className="flex cursor-pointer items-start gap-3 rounded-md px-2 py-2 text-sm text-ink hover:bg-control has-[:checked]:bg-control has-[:checked]:font-semibold">
                      <input
                        type="checkbox"
                        checked={selected.has(q.id)}
                        onChange={() => toggle(q.id)}
                        className="mt-0.5 size-4 shrink-0 accent-cta"
                      />
                      <span>
                        {q.stem}
                        {q.cohort_id ? (
                          <span className="ml-2 text-xs font-medium text-ink-3">
                            yours
                          </span>
                        ) : null}
                      </span>
                    </label>
                  </li>
                ))}
              </ul>
            </fieldset>
          ))}
        </div>
      </div>
    </form>
  )
}
