import { useState, type FormEvent } from 'react'
import {
  useAddCoFaculty,
  useAddTa,
  useCohortTas,
  useRemoveTa,
  useReportingPolicy,
  useSetReportingPolicy,
  type ReportingPolicy,
} from '../lib/api'
import { Alert, Button, Card, Spinner } from './ui'

const RESOLUTIONS: {
  value: ReportingPolicy['resolution']
  label: string
  consequence: string
}[] = [
  {
    value: 'per_student',
    label: 'Per student',
    consequence: 'You see named per-student progress.',
  },
  {
    value: 'pseudonymous',
    label: 'Pseudonymous',
    consequence:
      'You see per-student progress under stable pseudonyms, never names.',
  },
  {
    value: 'aggregate_only',
    label: 'Aggregate only',
    consequence: 'You see class-level statistics only.',
  },
]

function PolicyEditor({ cohortId }: { cohortId: string }) {
  const policy = useReportingPolicy(cohortId)
  if (policy.isPending) return <Spinner label="Loading policy" />
  if (policy.error) return <Alert tone="error">{policy.error.message}</Alert>
  if (!policy.data) return null
  return <PolicyForm cohortId={cohortId} initial={policy.data} />
}

// Separate form component: state initializes once from the loaded policy,
// so background refetches never clobber in-progress edits.
function PolicyForm({
  cohortId,
  initial,
}: {
  cohortId: string
  initial: ReportingPolicy
}) {
  const save = useSetReportingPolicy()
  const [resolution, setResolution] = useState<ReportingPolicy['resolution']>(
    initial.resolution,
  )
  const [identityDisplay, setIdentityDisplay] = useState<
    ReportingPolicy['identity_display']
  >(initial.identity_display)
  const [retention, setRetention] = useState<string>(
    initial.raw_retention_days === null ? '' : String(initial.raw_retention_days),
  )

  const submit = (e: FormEvent) => {
    e.preventDefault()
    save.mutate({
      cohortId,
      resolution,
      identityDisplay,
      retentionDays: retention === '' ? null : Number(retention),
    })
  }

  return (
    <Card>
      <h2 className="mb-1 text-sm font-semibold text-slate-900">
        Reporting policy
      </h2>
      <p className="mb-3 text-sm text-slate-500">
        Server-enforced. It changes what every report on this class shows,
        immediately, for everyone.
      </p>
      <form onSubmit={submit} className="flex flex-col gap-3">
        <fieldset>
          <legend className="sr-only">Reporting resolution</legend>
          <div className="flex flex-col gap-2">
            {RESOLUTIONS.map(r => (
              <label
                key={r.value}
                className="flex cursor-pointer items-start gap-3 rounded-md border border-slate-200 px-3 py-2"
              >
                <input
                  type="radio"
                  name="resolution"
                  value={r.value}
                  checked={resolution === r.value}
                  onChange={() => setResolution(r.value)}
                  className="mt-1"
                />
                <span>
                  <span className="block text-sm font-medium text-slate-900">
                    {r.label}
                  </span>
                  <span className="block text-xs text-slate-500">
                    {r.consequence}
                  </span>
                </span>
              </label>
            ))}
          </div>
        </fieldset>
        <div className="flex flex-wrap gap-4">
          <label className="text-sm text-slate-700">
            Identity shown
            <select
              value={identityDisplay}
              onChange={e =>
                setIdentityDisplay(
                  e.target.value as ReportingPolicy['identity_display'],
                )
              }
              className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
            >
              <option value="roster">Roster name</option>
              <option value="display_name">App handle</option>
              <option value="pseudonym">Pseudonym</option>
            </select>
          </label>
          <label className="text-sm text-slate-700">
            Raw data retention, days
            <input
              type="number"
              min={30}
              placeholder="default"
              value={retention}
              onChange={e => setRetention(e.target.value)}
              className="ml-2 w-24 rounded-md border border-slate-300 px-2 py-1 text-sm"
            />
          </label>
        </div>
        <div className="flex items-center gap-3">
          <Button type="submit" disabled={save.isPending}>
            Save reporting policy
          </Button>
          {save.isSuccess ? <Alert tone="success">Policy saved.</Alert> : null}
          {save.error ? <Alert tone="error">{save.error.message}</Alert> : null}
        </div>
      </form>
    </Card>
  )
}

function StaffEditor({ cohortId }: { cohortId: string }) {
  const tas = useCohortTas(cohortId)
  const addTa = useAddTa()
  const removeTa = useRemoveTa()
  const addCo = useAddCoFaculty()
  const [taEmail, setTaEmail] = useState('')
  const [coEmail, setCoEmail] = useState('')

  return (
    <Card>
      <h2 className="mb-1 text-sm font-semibold text-slate-900">Teaching staff</h2>
      <p className="mb-3 text-sm text-slate-500">
        TAs can run live sessions and see class aggregates; they never see
        per-student data. Co-instructors get full faculty access and need a
        redeemed faculty invite first.
      </p>
      <form
        className="flex flex-wrap items-end gap-2"
        onSubmit={(e: FormEvent) => {
          e.preventDefault()
          if (taEmail.trim()) {
            addTa.mutate({ cohortId, email: taEmail.trim() })
            setTaEmail('')
          }
        }}
      >
        <label className="text-sm text-slate-700">
          TA email
          <input
            type="email"
            value={taEmail}
            onChange={e => setTaEmail(e.target.value)}
            className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
          />
        </label>
        <Button type="submit" variant="ghost" disabled={addTa.isPending}>
          Add TA
        </Button>
      </form>
      {addTa.error ? (
        <div className="mt-2">
          <Alert tone="error">{addTa.error.message}</Alert>
        </div>
      ) : null}
      {tas.data && tas.data.length > 0 ? (
        <ul className="mt-3 flex flex-col gap-1">
          {tas.data.map(t => (
            <li
              key={t.user_id}
              className="flex items-center justify-between rounded-md bg-slate-50 px-3 py-1.5 text-sm"
            >
              <span>{t.display}</span>
              <Button
                variant="danger"
                onClick={() => removeTa.mutate({ cohortId, userId: t.user_id })}
              >
                Remove TA
              </Button>
            </li>
          ))}
        </ul>
      ) : null}
      <form
        className="mt-4 flex flex-wrap items-end gap-2 border-t border-slate-100 pt-4"
        onSubmit={(e: FormEvent) => {
          e.preventDefault()
          if (coEmail.trim()) {
            addCo.mutate({ cohortId, email: coEmail.trim() })
            setCoEmail('')
          }
        }}
      >
        <label className="text-sm text-slate-700">
          Co-instructor email
          <input
            type="email"
            value={coEmail}
            onChange={e => setCoEmail(e.target.value)}
            className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
          />
        </label>
        <Button type="submit" variant="ghost" disabled={addCo.isPending}>
          Add co-instructor
        </Button>
      </form>
      {addCo.error ? (
        <div className="mt-2">
          <Alert tone="error">{addCo.error.message}</Alert>
        </div>
      ) : null}
    </Card>
  )
}

export function SettingsTab({ cohortId }: { cohortId: string }) {
  return (
    <div className="flex flex-col gap-4">
      <PolicyEditor cohortId={cohortId} />
      <StaffEditor cohortId={cohortId} />
    </div>
  )
}
