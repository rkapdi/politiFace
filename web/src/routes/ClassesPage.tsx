import { useState, type FormEvent } from 'react'
import { GraduationCap } from 'lucide-react'
import { useCreateCohort, useMyClasses } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card } from '../components/ui'
import { EmptyState } from '../components/EmptyState'
import { SkeletonStats } from '../components/Skeleton'

function CreateClassCard() {
  const create = useCreateCohort()
  const [open, setOpen] = useState(false)
  const [name, setName] = useState('')
  const [term, setTerm] = useState('')
  const created = create.data as { join_code: string } | undefined

  if (created) {
    return (
      <Card>
        <h2 className="text-sm font-semibold text-slate-900">Class created</h2>
        <p className="mt-2 text-sm text-slate-600">
          Students join with this code in the app:
        </p>
        <p className="mt-1 text-3xl font-bold tracking-[0.3em] text-slate-900">
          {created.join_code}
        </p>
      </Card>
    )
  }

  if (!open) {
    return (
      <div>
        <Button onClick={() => setOpen(true)}>Create a class</Button>
      </div>
    )
  }

  const submit = (e: FormEvent) => {
    e.preventDefault()
    create.mutate({ name: name.trim(), term: term.trim() || null })
  }

  return (
    <Card>
      <h2 className="mb-3 text-sm font-semibold text-slate-900">
        Create a class
      </h2>
      <form onSubmit={submit} className="flex flex-wrap items-end gap-2">
        <label className="text-sm text-slate-700">
          Class name
          <input
            required
            minLength={3}
            value={name}
            onChange={e => setName(e.target.value)}
            className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
          />
        </label>
        <label className="text-sm text-slate-700">
          Term, optional
          <input
            value={term}
            placeholder="2026F"
            onChange={e => setTerm(e.target.value)}
            className="ml-2 w-24 rounded-md border border-slate-300 px-2 py-1 text-sm"
          />
        </label>
        <Button type="submit" disabled={create.isPending}>
          Create
        </Button>
        <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
          Cancel
        </Button>
      </form>
      {create.error ? (
        <div className="mt-2">
          <Alert tone="error">{create.error.message}</Alert>
        </div>
      ) : null}
    </Card>
  )
}

export function ClassesPage() {
  const { data, isPending, error } = useMyClasses()

  if (isPending) return <SkeletonStats count={2} />
  if (error) return <Alert tone="error">{error.message}</Alert>

  if (!data || data.length === 0) {
    return (
      <div className="flex flex-col gap-4">
        <EmptyState
          icon={GraduationCap}
          title={S.empty.classesTitle}
          hint={S.empty.classesHint}
        />
        <CreateClassCard />
      </div>
    )
  }

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-900">Your classes</h1>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        {data.map(c => (
          <Card key={c.cohort_id} className="hover:border-slate-400">
            <a
              href={`#/class/${c.cohort_id}`}
              className="text-base font-semibold text-slate-900 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900"
            >
              {c.name}
            </a>
            <div className="mt-1 flex items-center gap-2">
              {c.term ? <Badge>{c.term}</Badge> : null}
              <Badge tone={c.live_sessions > 0 ? 'green' : 'slate'}>
                {c.live_sessions} live session{c.live_sessions === 1 ? '' : 's'}
              </Badge>
            </div>
            <dl className="mt-3 grid grid-cols-4 gap-2 text-center">
              <div>
                <dt className="text-xs text-slate-500">Students</dt>
                <dd className="text-lg font-semibold">{c.students}</dd>
              </div>
              {c.active_7d === null ? (
                <div className="col-span-3 self-center text-xs text-slate-400">
                  {c.students === 0
                    ? 'No students yet, share the class code'
                    : 'Stats withheld for privacy (aggregate-only class under 5 students)'}
                </div>
              ) : (
                <>
                  <div>
                    <dt className="text-xs text-slate-500">Active 7d</dt>
                    <dd className="text-lg font-semibold">{c.active_7d}</dd>
                  </div>
                  <div>
                    <dt className="text-xs text-slate-500">Answers</dt>
                    <dd className="text-lg font-semibold">{c.answers_total}</dd>
                  </div>
                  <div>
                    <dt className="text-xs text-slate-500">Accuracy</dt>
                    <dd className="text-lg font-semibold">
                      {c.accuracy === null ? '' : `${Math.round(c.accuracy * 100)}%`}
                    </dd>
                  </div>
                </>
              )}
            </dl>
          </Card>
        ))}
      </div>
      <div className="mt-4">
        <CreateClassCard />
      </div>
    </div>
  )
}
