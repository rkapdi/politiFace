import { useMemo, useState } from 'react'
import { Download, Users } from 'lucide-react'
import {
  useAtRisk,
  useLogExport,
  useStudentProgress,
  type AtRiskRow,
  type ProgressRow,
} from '../lib/api'
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

const PASS_LINE = 48 // of 80

function readinessTone(r: number): 'red' | 'amber' | 'green' {
  if (r < 0.4) return 'red'
  if (r < 0.6) return 'amber'
  return 'green'
}

type StudentRow = {
  ref: string
  name: string
  risk?: AtRiskRow
  progress?: ProgressRow
}

// One row per student, in coaching order. Both RPCs key students by the same
// student_ref; a student only one of them returned still gets a row.
function mergeStudents(risk: AtRiskRow[], progress: ProgressRow[]): StudentRow[] {
  const byRef = new Map(progress.map(p => [p.student_ref, p]))
  const seen = new Set(risk.map(r => r.student_ref))
  return [
    ...risk.map(r => ({
      ref: r.student_ref,
      name: r.display_name,
      risk: r,
      progress: byRef.get(r.student_ref),
    })),
    ...progress
      .filter(p => !seen.has(p.student_ref))
      .map(p => ({ ref: p.student_ref, name: p.roster_name, progress: p })),
  ]
}

export function StudentsTab({ cohortId }: { cohortId: string }) {
  // Threshold above the model's ceiling: every student, coaching order.
  const atRisk = useAtRisk(cohortId, 1.01)
  const progress = useStudentProgress(cohortId)
  const logExport = useLogExport()
  const [filter, setFilter] = useState('')
  const [group, setGroup] = useState<'all' | 'below' | 'inactive'>('all')
  const students = useMemo(
    () => mergeStudents(atRisk.data ?? [], progress.data ?? []),
    [atRisk.data, progress.data],
  )

  if (atRisk.isPending || progress.isPending) {
    return <SkeletonTable rows={8} />
  }

  // aggregate_only classes: the RPCs refuse; show the explainer, no tables.
  const error = atRisk.error ?? progress.error
  if (error) return <Alert tone="info">{error.message}</Alert>

  const isBelow = (s: StudentRow) => s.risk !== undefined && s.risk.overall_readiness * 80 < PASS_LINE
  const isInactive = (s: StudentRow) => {
    const last = s.risk?.last_active ?? s.progress?.last_active ?? null
    return !last || Date.now() - Date.parse(last) >= 7 * 86400_000
  }
  const groups = [
    { id: 'all' as const, label: S.students.all, rows: students },
    { id: 'below' as const, label: S.students.belowPass, rows: students.filter(isBelow) },
    { id: 'inactive' as const, label: S.students.inactive, rows: students.filter(isInactive) },
  ]
  const inGroup = groups.find(g => g.id === group)!.rows
  const query = filter.trim().toLowerCase()
  const shown = query
    ? inGroup.filter(s => s.name.toLowerCase().includes(query))
    : inGroup

  const exportStudents = () => {
    logExport.mutate({ cohortId, kind: 'csv_progress' })
    downloadCsv(
      'class-students.csv',
      students.map(({ name, risk, progress: p }) => ({
        student: name,
        handle: p?.handle,
        readiness: risk?.overall_readiness,
        weakest_domain: risk?.weakest_domain_name,
        weakest_readiness: risk?.weakest_readiness,
        last_active: risk?.last_active ?? p?.last_active,
        answers_14d: risk?.answers_14d,
        answers: p?.answers_total,
        accuracy: p?.accuracy,
        mocks_completed: p?.mocks_completed,
        best_mock_score: p?.best_mock_score,
      })),
    )
  }

  return (
    <Card>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-base font-bold text-ink">
          Every student, lowest projected first
        </h2>
        <div className="flex items-center gap-2">
          <label className="text-sm text-ink-2">
            <span className="sr-only">{S.students.find}</span>
            <input
              type="search"
              value={filter}
              placeholder={S.students.find}
              onChange={e => setFilter(e.target.value)}
              className="rounded-md border border-field-line bg-field text-ink px-2 py-1.5 text-sm"
            />
          </label>
          <Button variant="ghost" onClick={exportStudents}>
            <Download aria-hidden="true" className="size-4" />
            {S.common.exportStudentsCsv}
          </Button>
        </div>
      </div>
      {students.length > 0 ? (
        <div role="group" aria-label={S.students.filterLabel} className="mb-3 flex flex-wrap gap-2">
          {groups.map(g => (
            <button
              key={g.id}
              type="button"
              aria-pressed={group === g.id}
              onClick={() => setGroup(g.id)}
              className="rounded-full bg-control px-3.5 py-1.5 text-[13px] font-semibold text-ink-2 hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus aria-pressed:bg-strong aria-pressed:font-bold aria-pressed:text-on-strong"
            >
              {g.label} <span className="tabular-nums">{g.rows.length}</span>
            </button>
          ))}
        </div>
      ) : null}
      {students.length === 0 ? (
        <EmptyState
          icon={Users}
          title={S.empty.studentsTitle}
          hint={S.empty.studentsHint}
        />
      ) : shown.length === 0 ? (
        <p className="py-4 text-sm text-ink-3">{S.students.noMatch}</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">
              Every student by projected score, lowest first; the pass line is
              48 of 80
            </caption>
            <thead>
              <tr className="border-b border-line text-left text-xs text-ink-3">
                <th scope="col" className="py-2 pr-3 font-medium">Student</th>
                <th scope="col" className="py-2 pr-3 font-medium">Projected</th>
                <th scope="col" className="py-2 pr-3 font-medium">Weakest domain</th>
                <th scope="col" className="py-2 pr-3 font-medium">Last active</th>
                <th scope="col" className="py-2 pr-3 font-medium">Answers, 14d</th>
                <th scope="col" className="py-2 pr-3 font-medium">Accuracy</th>
                <th scope="col" className="py-2 font-medium">Best mock</th>
              </tr>
            </thead>
            <tbody>
              {shown.map(({ ref, name, risk, progress: p }) => (
                <tr key={ref} className="border-b border-line last:border-b-0 hover:bg-raised">
                  <td className="py-3 pr-3">
                    <a
                      href={`#/class/${cohortId}/student/${encodeURIComponent(ref)}`}
                      className="font-semibold text-ink hover:underline"
                    >
                      {name}
                    </a>
                  </td>
                  <td className="py-3 pr-3">
                    {risk ? (
                      <Badge tone={readinessTone(risk.overall_readiness)}>
                        {Math.round(risk.overall_readiness * 80)} of 80
                      </Badge>
                    ) : (
                      'n/a'
                    )}
                  </td>
                  <td className="py-3 pr-3">
                    {risk?.weakest_domain_name ?? 'No data yet'}
                    {risk?.weakest_readiness != null
                      ? ` (${Math.round(risk.weakest_readiness * 100)}%)`
                      : ''}
                  </td>
                  <td className="py-3 pr-3">
                    {daysAgo(risk?.last_active ?? p?.last_active ?? null)}
                  </td>
                  <td className="py-3 pr-3">{risk?.answers_14d ?? 'n/a'}</td>
                  <td className="py-3 pr-3">
                    {p && p.answers_total > 0
                      ? `${Math.round(p.accuracy * 100)}%`
                      : 'n/a'}
                  </td>
                  <td className="py-3">
                    {p?.best_mock_score == null ? 'n/a' : `${p.best_mock_score}/80`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  )
}
