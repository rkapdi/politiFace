import { useState } from 'react'
import { useParams } from '@tanstack/react-router'
import * as Dialog from '@radix-ui/react-dialog'
import {
  useAssignPractice,
  useDrilldown,
  useLogExport,
  useSendAnnouncement,
  useStudentTrend,
} from '../lib/api'
import { downloadCsv } from '../lib/csv'
import { Alert, Button, Card, Spinner, Stat } from '../components/ui'
import { DomainBars } from '../components/DomainBars'
import { StudentTrendChart } from '../components/StudentTrendChart'
import { daysAgo } from '../components/StudentsTab'

export function StudentPage() {
  const { cohortId, studentRef } = useParams({ strict: false }) as {
    cohortId: string
    studentRef: string
  }
  return <StudentView cohortId={cohortId} studentRef={studentRef} />
}

export function MessageClassDialog({
  cohortId,
  prefill,
  open,
  onOpenChange,
}: {
  cohortId: string
  prefill: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const send = useSendAnnouncement()
  const [body, setBody] = useState(prefill)

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-slate-900/40" />
        <Dialog.Content className="fixed left-1/2 top-1/2 w-[min(28rem,90vw)] -translate-x-1/2 -translate-y-1/2 rounded-lg bg-white p-4 shadow-lg">
          <Dialog.Title className="text-base font-semibold text-slate-900">
            Message the class
          </Dialog.Title>
          <Dialog.Description className="mt-1 text-sm text-slate-500">
            Announcements go to the whole class in the app. Per-student
            messages are not supported, so keep it general.
          </Dialog.Description>
          <label htmlFor="announce-body" className="mt-3 block text-sm font-medium text-slate-700">
            Message
          </label>
          <textarea
            id="announce-body"
            rows={4}
            value={body}
            onChange={e => setBody(e.target.value)}
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900"
          />
          <div className="mt-3 flex justify-end gap-2">
            <Dialog.Close asChild>
              <Button variant="ghost">Cancel</Button>
            </Dialog.Close>
            <Button
              disabled={send.isPending || body.trim().length === 0}
              onClick={() =>
                send.mutate(
                  { cohortId, body: body.trim() },
                  { onSuccess: () => onOpenChange(false) },
                )
              }
            >
              Send to class
            </Button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}

export function StudentView({
  cohortId,
  studentRef,
}: {
  cohortId: string
  studentRef: string
}) {
  const { data, isPending, error } = useDrilldown(cohortId, studentRef)
  const trend = useStudentTrend(cohortId, studentRef)
  const assign = useAssignPractice()
  const logExport = useLogExport()
  const [messagePrefill, setMessagePrefill] = useState<string | null>(null)

  if (isPending) return <Spinner label="Loading student detail" />
  if (error) return <Alert tone="info">{error.message}</Alert>
  if (!data) return null

  const d = data

  const exportCsv = () => {
    logExport.mutate({ cohortId, kind: 'csv_drilldown' })
    downloadCsv(
      `student-${d.identity.display_name}.csv`,
      d.domains.map(dom => ({
        student: d.identity.display_name,
        domain: dom.name,
        readiness: dom.readiness,
        accuracy: dom.accuracy,
      })),
    )
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div>
          <a href={`#/class/${cohortId}`} className="text-sm text-slate-500 hover:underline">
            Back to class
          </a>
          <h1 className="text-xl font-semibold text-slate-900">
            {d.identity.display_name}
          </h1>
        </div>
        <Button variant="ghost" onClick={exportCsv}>
          Export CSV
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Stat label="Last active" value={daysAgo(d.activity.last_active)} />
        <Stat label="Answers, 7d" value={d.activity.answers_7d} />
        <Stat
          label="Accuracy"
          value={
            d.activity.answers_total > 0
              ? `${Math.round(d.activity.accuracy * 100)}%`
              : 'n/a'
          }
          hint={`${d.activity.answers_total} answers total`}
        />
        <Stat
          label="Best mock"
          value={d.mocks.best_score === null ? 'n/a' : `${d.mocks.best_score}/80`}
          hint={`${d.mocks.completed} completed`}
        />
      </div>

      {d.suggestions.length > 0 ? (
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-900">Next steps</h2>
          <ul className="flex flex-col gap-2">
            {d.suggestions.map(s => (
              <li
                key={s}
                className="flex items-center justify-between gap-3 rounded-md bg-slate-50 px-3 py-2 text-sm"
              >
                <span>{s}</span>
                <Button variant="ghost" onClick={() => setMessagePrefill(s)}>
                  Message class
                </Button>
              </li>
            ))}
          </ul>
        </Card>
      ) : null}

      {trend.data ? (
        <Card>
          <StudentTrendChart trend={trend.data} />
        </Card>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-900">
            Readiness by domain
          </h2>
          <DomainBars
            bars={d.domains.map(dom => ({
              label: dom.name,
              value: dom.readiness,
              metric: 'readiness',
            }))}
          />
          {d.domains.some(dom => (dom.readiness ?? 0) < 0.6) ? (
            <div className="mt-3 flex flex-wrap gap-2 border-t border-slate-100 pt-3">
              {d.domains
                .filter(dom => (dom.readiness ?? 0) < 0.6)
                .map(dom => (
                  <Button
                    key={dom.domain_id}
                    variant="ghost"
                    disabled={assign.isPending}
                    onClick={() =>
                      assign.mutate({ cohortId, domainId: dom.domain_id })
                    }
                  >
                    Assign {dom.name} practice
                  </Button>
                ))}
            </div>
          ) : null}
          {assign.isSuccess ? (
            <div className="mt-2">
              <Alert tone="success">
                Practice assigned and announced to the class. Retention
                checks run automatically at 7 and 21 days.
              </Alert>
            </div>
          ) : null}
          {assign.error ? (
            <div className="mt-2">
              <Alert tone="error">{assign.error.message}</Alert>
            </div>
          ) : null}
        </Card>
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-900">
            Weakest objectives
          </h2>
          {d.weak_objectives.length === 0 ? (
            <p className="text-sm text-slate-500">
              No objective is below 60% readiness.
            </p>
          ) : (
            <ul className="flex flex-col gap-2 text-sm">
              {d.weak_objectives.map(o => (
                <li key={o.objective_id} className="flex justify-between gap-3">
                  <span>
                    <span className="mr-2 text-xs text-slate-400">{o.code}</span>
                    {o.title}
                  </span>
                  <span className="font-medium text-amber-700">
                    {Math.round(o.readiness * 100)}%
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          Live sessions
        </h2>
        {d.live_sessions.length === 0 ? (
          <p className="text-sm text-slate-500">No live sessions attended yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <caption className="sr-only">Live session history</caption>
              <thead>
                <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
                  <th scope="col" className="py-2 pr-3 font-medium">Session</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Date</th>
                  <th scope="col" className="py-2 font-medium">Correct</th>
                </tr>
              </thead>
              <tbody>
                {d.live_sessions.map(s => (
                  <tr key={s.session_id} className="border-b border-slate-100">
                    <td className="py-2 pr-3">{s.title}</td>
                    <td className="py-2 pr-3">{s.held_at.slice(0, 10)}</td>
                    <td className="py-2">
                      {s.correct}/{s.answered}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {messagePrefill !== null ? (
        <MessageClassDialog
          cohortId={cohortId}
          prefill={messagePrefill}
          open={true}
          onOpenChange={open => {
            if (!open) setMessagePrefill(null)
          }}
        />
      ) : null}
    </div>
  )
}
