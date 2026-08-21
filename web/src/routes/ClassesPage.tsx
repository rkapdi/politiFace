import { useMyClasses } from '../lib/api'
import { Alert, Badge, Card, Spinner } from '../components/ui'

export function ClassesPage() {
  const { data, isPending, error } = useMyClasses()

  if (isPending) return <Spinner label="Loading your classes" />
  if (error) return <Alert tone="error">{error.message}</Alert>

  if (!data || data.length === 0) {
    return (
      <Card>
        <h1 className="text-lg font-semibold">No classes yet</h1>
        <p className="mt-2 text-sm text-slate-600">
          Create your class in the current faculty portal; this console picks
          it up automatically.
        </p>
      </Card>
    )
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold text-slate-900">Your classes</h1>
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
                  Stats appear at 5 students
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
    </div>
  )
}
