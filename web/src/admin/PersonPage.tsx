import { useState } from 'react'
import { Link, useParams } from '@tanstack/react-router'
import { useAdminPerson, useSetFaculty } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

const day = (iso: string | null) => (iso ? iso.slice(0, 10) : 'never')

export function PersonPage() {
  const { userId } = useParams({ strict: false }) as { userId: string }
  const person = useAdminPerson(userId)
  const setFaculty = useSetFaculty()
  const [confirming, setConfirming] = useState(false)
  if (person.isPending) return <p>{A.loading}</p>
  if (person.error || !person.data) return <p className="sev-fail">{person.error?.message}</p>
  const p = person.data
  const id = p.identity
  const name = p.memberships.find(m => m.roster_name)?.roster_name ?? id.handle
  const grant = !id.is_faculty

  return (
    <ThreePane
      header={
        <>
          <span className="admin-label">Person</span>
          <h1 className="admin-strong text-sm font-bold">{name}</h1>
          <span>{id.email}</span>
          <span className="text-[var(--a-muted)]">{id.handle}</span>
          <span className="flex-1" />
          {id.is_admin ? <span className="sev-info">ADMIN</span> : null}
          {id.is_faculty ? <span className="sev-ok">INSTRUCTOR</span> : null}
          {p.memberships.some(m => m.role === 'student') ? <span className="sev-ok">STUDENT</span> : null}
        </>
      }
      left={
        <>
          <div className="admin-label">Classes</div>
          {p.memberships.map(m => (
            <div key={m.cohort_id}>
              <Link to="/admin/classes/$cohortId" params={{ cohortId: m.cohort_id }}>▸ {m.name}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{m.role}{m.roster_name ? ` · ${m.roster_name}` : ''}</div>
            </div>
          ))}
          <div className="admin-label mt-2">Live sessions</div>
          {p.sessions.map(s => (
            <div key={s.session_id}>
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }}>▸ {s.title}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{s.correct}/{s.answered} correct</div>
            </div>
          ))}
          <div className="admin-label mt-2">Devices</div>
          {p.devices.map((d, i) => (
            <div key={i} className="text-[var(--a-muted)]">▸ {(d.user_agent ?? 'unknown').slice(0, 40)}</div>
          ))}
          <div className="text-[var(--a-muted)]">push devices: {p.push_devices}</div>
        </>
      }
      center={<Timeline entries={p.timeline} />}
      right={
        <>
          <div className="admin-label">Properties</div>
          <div>created {day(id.created_at)}</div>
          <div>last sign-in {day(id.last_sign_in_at)}</div>
          <div>school {id.school ?? 'none'}</div>
          <div>iOS app {p.app_versions.ios ?? 'not seen'}</div>
          <div>web {p.app_versions.web ?? 'not seen'}</div>
          <div>practice 30d {p.practice.correct_30d}/{p.practice.answers_30d}</div>
          <div className="admin-label mt-3">Actions</div>
          {confirming ? (
            <div className="mt-1 border border-[var(--a-warn)] p-2">
              <p>{grant ? 'Grant' : 'Revoke'} instructor access for {name}?</p>
              <button type="button" className="mr-2 border border-[var(--a-line)] px-2" onClick={() => {
                setFaculty.mutate({ userId: id.user_id, verified: grant })
                setConfirming(false)
              }}>Confirm</button>
              <button type="button" className="border border-[var(--a-line)] px-2" onClick={() => setConfirming(false)}>Cancel</button>
            </div>
          ) : (
            <button type="button" className="mt-1 block w-full border border-[var(--a-line)] px-2 py-1 text-left" onClick={() => setConfirming(true)}>
              {grant ? 'Grant instructor access' : 'Revoke instructor access'}
            </button>
          )}
          {setFaculty.error ? <p className="sev-fail">{setFaculty.error.message}</p> : null}
          {['Move class', 'Sign out everywhere', 'Rename', 'Delete account'].map(label => (
            <button key={label} type="button" disabled title={A.comingIn2b}
              className="mt-1 block w-full cursor-not-allowed border border-[var(--a-line)] px-2 py-1 text-left text-[var(--a-muted)]">
              {label}
            </button>
          ))}
        </>
      }
    />
  )
}
