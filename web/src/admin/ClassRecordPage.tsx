import { Link, useParams } from '@tanstack/react-router'
import { useAdminClass } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

export function ClassRecordPage() {
  const { cohortId } = useParams({ strict: false }) as { cohortId: string }
  const rec = useAdminClass(cohortId)
  if (rec.isPending) return <p>{A.loading}</p>
  if (rec.error || !rec.data) return <p className="sev-fail">{rec.error?.message}</p>
  const c = rec.data
  return (
    <ThreePane
      header={
        <>
          <span className="admin-label">{A.titles.klass}</span>
          <h1 className="admin-strong text-sm font-bold">{c.facts.name}</h1>
          <span className="text-[var(--a-muted)]">{c.facts.term ?? ''}</span>
          <span className="flex-1" />
          <span>{A.klass.owner} {c.facts.owner ?? A.klass.unknown}</span>
        </>
      }
      left={
        <>
          <div className="admin-label">{A.klass.membersLabel} ({c.members.length})</div>
          {c.members.map(m => (
            <div key={m.user_id}>
              <Link to="/admin/people/$userId" params={{ userId: m.user_id }}>
                ▸ {m.roster_name ?? m.handle ?? A.klass.unknown}
              </Link>
              <div className="pl-3 text-[var(--a-muted)]">{m.role} · {m.email ?? ''}</div>
            </div>
          ))}
          <div className="admin-label mt-2">{A.klass.sessionsLabel}</div>
          {c.sessions.map(s => (
            <div key={s.session_id}>
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }}>▸ {s.title}</Link>
              <div className="pl-3 text-[var(--a-muted)]">{s.status} · {s.participants} {A.klass.joined}</div>
            </div>
          ))}
        </>
      }
      center={<Timeline entries={c.timeline} />}
      right={
        <>
          <div className="admin-label">{A.klass.properties}</div>
          <div>{A.klass.joinCode} <span className="admin-strong">{c.facts.join_code}</span></div>
          <div>{A.klass.reporting} {c.facts.reporting_resolution ?? A.klass.reportingDefault}</div>
          <div>{A.klass.created} {c.facts.created_at.slice(0, 10)}</div>
          <div className="admin-label mt-3">{A.klass.funnel}</div>
          <div>{A.klass.members} {c.funnel.members}</div>
          <div>{A.klass.students} {c.funnel.students}</div>
          <div>{A.klass.answeredLive} {c.funnel.answered_live}</div>
          <div>{A.klass.practiced7d} {c.funnel.practiced_7d}</div>
        </>
      }
    />
  )
}
