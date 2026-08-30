import { useState } from 'react'
import { Radio } from 'lucide-react'
import { useCohortSessions } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card } from './ui'
import { EmptyState } from './EmptyState'
import { SkeletonTable } from './Skeleton'
import { QuestionPicker } from './QuestionPicker'

export function LiveTab({ cohortId }: { cohortId: string }) {
  const sessions = useCohortSessions(cohortId)
  const [composing, setComposing] = useState(false)

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-900">
            Run a live session
          </h2>
          {!composing ? (
            <Button onClick={() => setComposing(true)}>Set one up</Button>
          ) : null}
        </div>
        {composing ? (
          <QuestionPicker
            cohortId={cohortId}
            onCreated={sessionId => {
              window.location.hash = `#/class/${cohortId}/live/${sessionId}`
            }}
          />
        ) : (
          <p className="text-sm text-slate-500">
            Students join from any browser with a code, no app needed. Answers
            grade server-side and feed the class analytics.
          </p>
        )}
      </Card>
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
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
                <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
                  <th scope="col" className="py-2 pr-3 font-medium">Session</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Status</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Participants</th>
                  <th scope="col" className="py-2 font-medium">Avg correct</th>
                </tr>
              </thead>
              <tbody>
                {sessions.data.map(s => (
                  <tr key={s.session_id} className="border-b border-slate-100">
                    <td className="py-2 pr-3">
                      <a
                        href={`#/class/${cohortId}/live/${s.session_id}`}
                        className="font-medium text-slate-900 hover:underline"
                      >
                        {s.title}
                      </a>
                    </td>
                    <td className="py-2 pr-3">
                      <Badge tone={s.status === 'ended' ? 'slate' : 'green'}>
                        {s.status}
                      </Badge>
                    </td>
                    <td className="py-2 pr-3">{s.participants}</td>
                    <td className="py-2">
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
