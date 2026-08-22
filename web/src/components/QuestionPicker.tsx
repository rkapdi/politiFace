import { useMemo, useState, type FormEvent } from 'react'
import {
  useCreateLiveSession,
  useDomains,
  usePickableQuestions,
} from '../lib/api'
import { Alert, Badge, Button, Spinner } from './ui'

export function QuestionPicker({
  cohortId,
  onCreated,
}: {
  cohortId: string
  onCreated: (sessionId: string) => void
}) {
  const questions = usePickableQuestions(cohortId)
  const domains = useDomains()
  const create = useCreateLiveSession()
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [title, setTitle] = useState('')
  const [seconds, setSeconds] = useState(20)

  const byDomain = useMemo(() => {
    const groups = new Map<number, typeof questions.data>()
    for (const q of questions.data ?? []) {
      const list = groups.get(q.domain_id) ?? []
      list.push(q)
      groups.set(q.domain_id, list)
    }
    return groups
  }, [questions.data])

  if (questions.isPending || domains.isPending) {
    return <Spinner label="Loading question bank" />
  }
  if (questions.error) {
    return <Alert tone="error">{questions.error.message}</Alert>
  }

  const toggle = (id: string) => {
    setSelected(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const submit = (e: FormEvent) => {
    e.preventDefault()
    create.mutate(
      {
        cohortId,
        title: title.trim(),
        questionIds: [...selected],
        questionSeconds: seconds,
      },
      { onSuccess: data => onCreated((data as { id: string }).id) },
    )
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-3">
      <div className="flex flex-wrap items-end gap-3">
        <label className="text-sm text-slate-700">
          Session title
          <input
            required
            minLength={3}
            maxLength={80}
            value={title}
            onChange={e => setTitle(e.target.value)}
            className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
          />
        </label>
        <label className="text-sm text-slate-700">
          Seconds per question
          <select
            value={seconds}
            onChange={e => setSeconds(Number(e.target.value))}
            className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
          >
            {[10, 15, 20, 30, 45, 60].map(s => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        </label>
        <Badge tone={selected.size > 0 ? 'green' : 'slate'}>
          {selected.size} selected
        </Badge>
        <Button type="submit" disabled={selected.size === 0 || create.isPending}>
          Start session
        </Button>
      </div>
      {create.error ? <Alert tone="error">{create.error.message}</Alert> : null}
      <div className="max-h-96 overflow-y-auto rounded-md border border-slate-200">
        {[...byDomain.entries()].map(([domainId, qs]) => (
          <fieldset key={domainId} className="border-b border-slate-100 p-3">
            <legend className="px-1 text-xs font-semibold text-slate-500">
              {domains.data?.find(d => d.id === domainId)?.name ??
                `Domain ${domainId}`}
            </legend>
            <ul className="flex flex-col gap-1">
              {(qs ?? []).map(q => (
                <li key={q.id}>
                  <label className="flex cursor-pointer items-start gap-2 rounded px-1 py-0.5 text-sm hover:bg-slate-50">
                    <input
                      type="checkbox"
                      checked={selected.has(q.id)}
                      onChange={() => toggle(q.id)}
                      className="mt-1"
                    />
                    <span>
                      {q.stem}
                      {q.cohort_id ? (
                        <span className="ml-2 text-xs text-slate-400">
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
    </form>
  )
}
