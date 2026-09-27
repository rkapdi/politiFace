import { useId, useState, type FormEvent } from 'react'
import { PencilLine } from 'lucide-react'
import {
  useDomains,
  useOwnQuestions,
  useRetireOwnQuestion,
  useSaveOwnQuestion,
  type OwnQuestion,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card } from './ui'
import { EmptyState } from './EmptyState'
import { SkeletonTable } from './Skeleton'

const KEYS = ['A', 'B', 'C', 'D'] as const
const input =
  'mt-1 w-full rounded-md border border-slate-300 px-2 py-1.5 text-sm text-slate-900'

type Form = {
  stem: string
  domainId: number | null
  options: Record<string, string>
  answerKey: string
  explanation: string
  citation: string
}

const blankForm = (): Form => ({
  stem: '',
  domainId: null,
  options: { A: '', B: '', C: '', D: '' },
  answerKey: '',
  explanation: '',
  citation: '',
})

// Editing starts from the saved wording, but the answer key is server-only,
// so the instructor confirms the correct answer again.
const formFrom = (q: OwnQuestion): Form => ({
  ...blankForm(),
  stem: q.stem,
  domainId: q.domain_id,
  options: Object.fromEntries(
    KEYS.map((k, i) => [k, q.options[i]?.text ?? '']),
  ),
})

function validate(form: Form): string | null {
  if (form.stem.trim().length < 10) return S.ownQuestions.stemShort
  const filled = KEYS.filter(k => form.options[k].trim().length > 0)
  if (filled.length < 2) return S.ownQuestions.optionsShort
  if (!form.answerKey) return S.ownQuestions.pickCorrect
  if (form.options[form.answerKey].trim().length === 0) {
    return S.ownQuestions.correctBlank
  }
  return null
}

function QuestionForm({
  cohortId,
  editing,
  onDone,
}: {
  cohortId: string
  editing: OwnQuestion | null
  onDone: () => void
}) {
  const domains = useDomains()
  const save = useSaveOwnQuestion()
  const [form, setForm] = useState<Form>(() =>
    editing ? formFrom(editing) : blankForm(),
  )
  const [problem, setProblem] = useState<string | null>(null)
  const id = useId()
  const domainId = form.domainId ?? domains.data?.[0]?.id ?? null

  const submit = (e: FormEvent) => {
    e.preventDefault()
    const invalid = validate(form)
    setProblem(invalid)
    if (invalid || domainId === null) return
    save.mutate(
      {
        cohortId,
        domainId,
        stem: form.stem.trim(),
        options: KEYS.filter(k => form.options[k].trim().length > 0).map(k => ({
          key: k,
          text: form.options[k].trim(),
        })),
        answerKey: form.answerKey,
        explanation: form.explanation.trim(),
        citation: form.citation.trim(),
        replaces: editing?.id,
      },
      { onSuccess: onDone },
    )
  }

  return (
    <form onSubmit={submit} noValidate className="flex flex-col gap-3">
      {editing ? <Alert tone="info">{S.ownQuestions.editNote}</Alert> : null}
      <label className="text-sm text-slate-700">
        {S.ownQuestions.stem}
        <textarea
          required
          rows={2}
          maxLength={500}
          value={form.stem}
          onChange={e => setForm({ ...form, stem: e.target.value })}
          className={input}
        />
      </label>
      <label className="text-sm text-slate-700">
        {S.ownQuestions.domain}
        <select
          value={domainId ?? ''}
          onChange={e => setForm({ ...form, domainId: Number(e.target.value) })}
          className={input}
        >
          {(domains.data ?? []).map(d => (
            <option key={d.id} value={d.id}>
              {d.name}
            </option>
          ))}
        </select>
      </label>
      <fieldset className="flex flex-col gap-2">
        <legend className="text-sm text-slate-700">
          {S.ownQuestions.correct}
        </legend>
        {KEYS.map(k => (
          <div key={k} className="flex items-center gap-2">
            <input
              type="radio"
              name={`${id}-correct`}
              aria-label={`${S.ownQuestions.option} ${k} is correct`}
              checked={form.answerKey === k}
              onChange={() => setForm({ ...form, answerKey: k })}
            />
            <input
              aria-label={`${S.ownQuestions.option} ${k}`}
              placeholder={`${S.ownQuestions.option} ${k}`}
              maxLength={200}
              value={form.options[k]}
              onChange={e =>
                setForm({
                  ...form,
                  options: { ...form.options, [k]: e.target.value },
                })
              }
              className={`${input} mt-0`}
            />
          </div>
        ))}
      </fieldset>
      <label className="text-sm text-slate-700">
        {S.ownQuestions.explanation}
        <textarea
          rows={2}
          maxLength={500}
          value={form.explanation}
          onChange={e => setForm({ ...form, explanation: e.target.value })}
          className={input}
        />
      </label>
      <label className="text-sm text-slate-700">
        {S.ownQuestions.citation}
        <input
          maxLength={300}
          value={form.citation}
          onChange={e => setForm({ ...form, citation: e.target.value })}
          className={input}
        />
      </label>
      {problem ? <Alert tone="error">{problem}</Alert> : null}
      {save.error ? <Alert tone="error">{save.error.message}</Alert> : null}
      <div className="flex gap-2">
        <Button type="submit" disabled={save.isPending}>
          {editing ? S.ownQuestions.update : S.ownQuestions.create}
        </Button>
        <Button type="button" variant="ghost" onClick={onDone}>
          {S.common.cancel}
        </Button>
      </div>
    </form>
  )
}

/** Faculty-only: write, revise, and remove this class's own questions. */
export function OwnQuestions({
  cohortId,
  onRemoved,
}: {
  cohortId: string
  // Lets the caller drop a retired question from a session being built.
  onRemoved?: (questionId: string) => void
}) {
  const questions = useOwnQuestions(cohortId)
  const domains = useDomains()
  const retire = useRetireOwnQuestion()
  // 'new', a question id being edited, or null when the form is closed.
  const [open, setOpen] = useState<string | null>(null)
  const [confirming, setConfirming] = useState<string | null>(null)

  const editing = questions.data?.find(q => q.id === open) ?? null

  return (
    <Card>
      <div className="mb-3 flex items-center justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold text-slate-900">
            {S.ownQuestions.heading}
          </h2>
          <p className="text-sm text-slate-500">{S.ownQuestions.hint}</p>
        </div>
        {open === null ? (
          <Button variant="ghost" onClick={() => setOpen('new')}>
            {S.ownQuestions.add}
          </Button>
        ) : null}
      </div>
      {open !== null ? (
        <QuestionForm
          key={open}
          cohortId={cohortId}
          editing={editing}
          onDone={() => {
            if (editing) onRemoved?.(editing.id)
            setOpen(null)
          }}
        />
      ) : null}
      {questions.isPending ? <SkeletonTable rows={2} /> : null}
      {questions.error ? (
        <Alert tone="error">{questions.error.message}</Alert>
      ) : null}
      {retire.error ? <Alert tone="error">{retire.error.message}</Alert> : null}
      {open === null && questions.data && questions.data.length === 0 ? (
        <EmptyState
          icon={PencilLine}
          title={S.ownQuestions.emptyTitle}
          hint={S.ownQuestions.emptyHint}
        />
      ) : null}
      {open === null && questions.data && questions.data.length > 0 ? (
        <ul className="flex flex-col divide-y divide-slate-100">
          {questions.data.map(q => (
            <li
              key={q.id}
              className="flex flex-wrap items-start justify-between gap-3 py-2"
            >
              <div className="min-w-0 flex-1">
                <p className="text-sm text-slate-900">{q.stem}</p>
                <p className="text-xs text-slate-500">
                  {domains.data?.find(d => d.id === q.domain_id)?.name ??
                    `Domain ${q.domain_id}`}
                </p>
              </div>
              {confirming === q.id ? (
                <div className="flex flex-col items-end gap-1">
                  <p className="text-xs text-slate-500">
                    {S.ownQuestions.confirmRemove} {S.ownQuestions.removeHint}
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="danger"
                      disabled={retire.isPending}
                      onClick={() =>
                        retire.mutate(
                          { cohortId, questionId: q.id },
                          {
                            onSuccess: () => {
                              onRemoved?.(q.id)
                              setConfirming(null)
                            },
                          },
                        )
                      }
                    >
                      {S.ownQuestions.remove}
                    </Button>
                    <Button variant="ghost" onClick={() => setConfirming(null)}>
                      {S.common.cancel}
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="flex gap-2">
                  <Button
                    variant="ghost"
                    aria-label={`${S.ownQuestions.edit}: ${q.stem}`}
                    onClick={() => setOpen(q.id)}
                  >
                    {S.ownQuestions.edit}
                  </Button>
                  <Button
                    variant="ghost"
                    aria-label={`${S.ownQuestions.remove}: ${q.stem}`}
                    onClick={() => setConfirming(q.id)}
                  >
                    {S.ownQuestions.remove}
                  </Button>
                </div>
              )}
            </li>
          ))}
        </ul>
      ) : null}
    </Card>
  )
}
