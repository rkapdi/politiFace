import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from '@tanstack/react-router'
import { useAdminPerson, useSetFaculty } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

const day = (iso: string | null) => (iso ? iso.slice(0, 10) : A.person.never)

export function PersonPage() {
  const { userId } = useParams({ strict: false }) as { userId: string }
  const person = useAdminPerson(userId)
  const setFaculty = useSetFaculty()
  const [confirming, setConfirming] = useState(false)
  const actionBtnRef = useRef<HTMLButtonElement>(null)
  const confirmBtnRef = useRef<HTMLButtonElement>(null)
  const wasConfirmingRef = useRef(false)

  // Focus follows the confirm flow: into the Confirm button when it
  // appears, back to the action button once it is dismissed either way.
  useEffect(() => {
    if (confirming) {
      confirmBtnRef.current?.focus()
      wasConfirmingRef.current = true
    } else if (wasConfirmingRef.current) {
      actionBtnRef.current?.focus()
      wasConfirmingRef.current = false
    }
  }, [confirming])

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
          <span className="admin-label">{A.person.kind}</span>
          <h1 className="admin-strong text-sm font-bold">{name}</h1>
          <span>{id.email}</span>
          <span className="text-[var(--a-muted)]">{id.handle}</span>
          <span className="flex-1" />
          {id.is_admin ? <span className="sev-info">{A.person.badgeAdmin}</span> : null}
          {id.is_faculty ? <span className="sev-ok">{A.person.badgeInstructor}</span> : null}
          {p.memberships.some(m => m.role === 'student') ? <span className="sev-ok">{A.person.badgeStudent}</span> : null}
        </>
      }
      left={
        <>
          <div className="admin-label">{A.person.classes}</div>
          {p.memberships.map(m => (
            <div key={m.cohort_id}>
              <Link to="/admin/classes/$cohortId" params={{ cohortId: m.cohort_id }}>▸ {m.name}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{m.role}{m.roster_name ? ` · ${m.roster_name}` : ''}</div>
            </div>
          ))}
          <div className="admin-label mt-2">{A.person.liveSessions}</div>
          {p.sessions.map(s => (
            <div key={s.session_id}>
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }}>▸ {s.title}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{s.correct}/{s.answered} correct</div>
            </div>
          ))}
          <div className="admin-label mt-2">{A.person.devices}</div>
          {p.devices.map((d, i) => (
            <div key={i} className="text-[var(--a-muted)]">▸ {(d.user_agent ?? A.person.unknown).slice(0, 40)}</div>
          ))}
          <div className="text-[var(--a-muted)]">{A.person.pushDevices}: {p.push_devices}</div>
        </>
      }
      center={<Timeline entries={p.timeline} />}
      right={
        <>
          <div className="admin-label">{A.person.properties}</div>
          <div>{A.person.created} {day(id.created_at)}</div>
          <div>{A.person.lastSignIn} {day(id.last_sign_in_at)}</div>
          <div>{A.person.school} {id.school ?? A.person.none}</div>
          <div>{A.person.iosApp} {p.app_versions.ios ?? A.person.notSeen}</div>
          <div>{A.person.web} {p.app_versions.web ?? A.person.notSeen}</div>
          <div>{A.person.practice30d} {p.practice.correct_30d}/{p.practice.answers_30d}</div>
          <div className="admin-label mt-3">{A.person.actions}</div>
          {confirming ? (
            <div role="group" aria-label={A.person.confirmGroupLabel} className="mt-1 border border-[var(--a-warn)] p-2">
              <p>{grant ? A.person.confirmGrant : A.person.confirmRevoke} {A.person.confirmSuffix} {name}?</p>
              <button ref={confirmBtnRef} type="button" className="mr-2 border border-[var(--a-line)] px-2" onClick={() => {
                setFaculty.mutate({ userId: id.user_id, verified: grant })
                setConfirming(false)
              }}>{A.person.confirm}</button>
              <button type="button" className="border border-[var(--a-line)] px-2" onClick={() => setConfirming(false)}>{A.person.cancel}</button>
            </div>
          ) : (
            <button ref={actionBtnRef} type="button" className="mt-1 block w-full border border-[var(--a-line)] px-2 py-1 text-left" onClick={() => setConfirming(true)}>
              {grant ? A.person.grant : A.person.revoke}
            </button>
          )}
          {setFaculty.error ? <p className="sev-fail">{setFaculty.error.message}</p> : null}
          {A.person.disabledActions.map(label => (
            <button key={label} type="button" disabled title={A.comingIn2b}
              className="mt-1 block w-full cursor-not-allowed border border-[var(--a-line)] px-2 py-1 text-left text-[var(--a-muted)]">
              {label}
            </button>
          ))}
          <p className="text-[var(--a-muted)]">{A.comingIn2b}</p>
        </>
      }
    />
  )
}
