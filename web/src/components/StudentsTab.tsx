import { Download, Users } from 'lucide-react'
import { useAtRisk, useLogExport, useStudentProgress } from '../lib/api'
import { downloadCsv } from '../lib/csv'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card } from './ui'
import { EmptyState } from './EmptyState'
import { SkeletonTable } from './Skeleton'

export function daysAgo(iso: string | null): string {
  if (!iso) return 'never'
  const days = Math.floor((Date.now() - Date.parse(iso)) / 86400_000)
  if (days <= 0) return 'today'
  if (days === 1) return '1 day ago'
  return `${days} days ago`
}

function readinessTone(r: number): 'red' | 'amber' | 'green' {
  if (r < 0.4) return 'red'
  if (r < 0.6) return 'amber'
  return 'green'
}

export function StudentsTab({ cohortId }: { cohortId: string }) {
  // Threshold above the model's ceiling: every student, coaching order.
  const atRisk = useAtRisk(cohortId, 1.01)
  const progress = useStudentProgress(cohortId)
  const logExport = useLogExport()

  if (atRisk.isPending || progress.isPending) {
    return <SkeletonTable rows={8} />
  }

  // aggregate_only classes: the RPCs refuse; show the explainer, no tables.
  const error = atRisk.error ?? progress.error
  if (error) return <Alert tone="info">{error.message}</Alert>

  const atRiskRows = atRisk.data ?? []
  const progressRows = progress.data ?? []

  const exportAtRisk = () => {
    logExport.mutate({ cohortId, kind: 'csv_at_risk' })
    downloadCsv(
      'at-risk.csv',
      atRiskRows.map(r => ({
        student: r.display_name,
        readiness: r.overall_readiness,
        weakest_domain: r.weakest_domain_name,
        weakest_readiness: r.weakest_readiness,
        last_active: r.last_active,
        answers_14d: r.answers_14d,
      })),
    )
  }

  const exportProgress = () => {
    logExport.mutate({ cohortId, kind: 'csv_progress' })
    downloadCsv(
      'class-progress.csv',
      progressRows.map(r => ({
        student: r.roster_name,
        handle: r.handle,
        last_active: r.last_active,
        answers: r.answers_total,
        accuracy: r.accuracy,
        mocks_completed: r.mocks_completed,
        best_mock_score: r.best_mock_score,
      })),
    )
  }

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-900">
            Every student, lowest projected first
          </h2>
          <Button variant="ghost" onClick={exportAtRisk}>
            <Download aria-hidden="true" className="size-4" />
            {S.common.exportStudentsCsv}
          </Button>
        </div>
        {atRiskRows.length === 0 ? (
          <EmptyState
            icon={Users}
            title={S.empty.studentsTitle}
            hint={S.empty.studentsHint}
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <caption className="sr-only">
                Every student by projected score, lowest first; the pass
                line is 48 of 80
              </caption>
              <thead>
                <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
                  <th scope="col" className="py-2 pr-3 font-medium">Student</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Projected</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Weakest domain</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Last active</th>
                  <th scope="col" className="py-2 font-medium">Answers, 14d</th>
                </tr>
              </thead>
              <tbody>
                {atRiskRows.map(r => (
                  <tr key={r.student_ref} className="border-b border-slate-100">
                    <td className="py-2 pr-3">
                      <a
                        href={`#/class/${cohortId}/student/${encodeURIComponent(r.student_ref)}`}
                        className="font-medium text-slate-900 hover:underline"
                      >
                        {r.display_name}
                      </a>
                    </td>
                    <td className="py-2 pr-3">
                      <Badge tone={readinessTone(r.overall_readiness)}>
                        {Math.round(r.overall_readiness * 80)} of 80
                      </Badge>
                    </td>
                    <td className="py-2 pr-3">
                      {r.weakest_domain_name ?? 'No data yet'}
                      {r.weakest_readiness !== null
                        ? ` (${Math.round(r.weakest_readiness * 100)}%)`
                        : ''}
                    </td>
                    <td className="py-2 pr-3">{daysAgo(r.last_active)}</td>
                    <td className="py-2">{r.answers_14d}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-900">Practice detail</h2>
          <Button variant="ghost" onClick={exportProgress}>
            <Download aria-hidden="true" className="size-4" />
            {S.common.exportClassCsv}
          </Button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">Class progress</caption>
            <thead>
              <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
                <th scope="col" className="py-2 pr-3 font-medium">Student</th>
                <th scope="col" className="py-2 pr-3 font-medium">Last active</th>
                <th scope="col" className="py-2 pr-3 font-medium">Answers</th>
                <th scope="col" className="py-2 pr-3 font-medium">Accuracy</th>
                <th scope="col" className="py-2 font-medium">Best mock</th>
              </tr>
            </thead>
            <tbody>
              {progressRows.map(r => (
                <tr key={r.student_ref} className="border-b border-slate-100">
                  <td className="py-2 pr-3">
                    <a
                      href={`#/class/${cohortId}/student/${encodeURIComponent(r.student_ref)}`}
                      className="font-medium text-slate-900 hover:underline"
                    >
                      {r.roster_name}
                    </a>
                  </td>
                  <td className="py-2 pr-3">{daysAgo(r.last_active)}</td>
                  <td className="py-2 pr-3">{r.answers_total}</td>
                  <td className="py-2 pr-3">
                    {r.answers_total > 0
                      ? `${Math.round(r.accuracy * 100)}%`
                      : 'n/a'}
                  </td>
                  <td className="py-2">
                    {r.best_mock_score === null ? 'n/a' : `${r.best_mock_score}/80`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}
