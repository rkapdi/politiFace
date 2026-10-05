import { Link } from '@tanstack/react-router'
import { useAdminActivity, useAdminHome } from './adminApi'
import { A } from './strings'

const time = (iso: string) =>
  new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })

function Stat({ label, value, tone }: { label: string; value: string | number; tone?: string }) {
  return (
    <div className="admin-panel p-2">
      <div className="admin-label">{label}</div>
      <div className={`text-lg ${tone ?? 'admin-strong'}`}>{value}</div>
    </div>
  )
}

export function AdminHome() {
  const home = useAdminHome()
  const activity = useAdminActivity()
  if (home.isPending) return <p>{A.loading}</p>
  if (home.error || !home.data) return <p className="sev-fail">{home.error?.message}</p>
  const h = home.data
  const nominal = h.health?.ok !== false
  return (
    <div className="flex flex-col gap-2">
      <h1 className="sr-only">{A.titles.home}</h1>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-5">
        <Stat label="People" value={h.totals.people} />
        <Stat label="Students enrolled" value={h.totals.students} />
        <Stat label="Answered live (7d)" value={h.totals.answered_live_7d} />
        <Stat label="Pending requests" value={h.pending_requests} tone={h.pending_requests > 0 ? 'sev-warn' : undefined} />
        <Stat label="System" value={nominal ? 'NOMINAL' : 'CHECK'} tone={nominal ? 'sev-ok' : 'sev-fail'} />
      </div>
      <div className="grid gap-2 lg:grid-cols-[1.25fr_1fr]">
        <section className="admin-panel p-2" aria-label="Live now">
          <h2 className="admin-label mb-1">Live now</h2>
          {h.live_now.length === 0 ? <p className="text-[var(--a-muted)]">No live sessions.</p> : null}
          {h.live_now.map(s => (
            <div key={s.session_id} className="mb-1 border-l-2 border-[var(--a-ok)] pl-2">
              <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }} className="admin-strong">
                {s.title}
              </Link>{' '}
              · {s.class} · Q{s.index + 1}/{s.total} · {s.participants} in room
              <div className="text-[var(--a-muted)]">{s.professor} · started {time(s.created_at)}</div>
            </div>
          ))}
          <h2 className="admin-label mb-1 mt-3">Onboarding funnel</h2>
          <table className="w-full">
            <thead>
              <tr className="admin-label text-left">
                <th scope="col">Class</th><th scope="col">Members</th><th scope="col">Students</th>
                <th scope="col">Answered live</th><th scope="col">Practiced 7d</th>
              </tr>
            </thead>
            <tbody>
              {h.funnel.map(f => (
                <tr key={f.cohort_id} className="border-t border-[var(--a-line)]">
                  <td>
                    <Link to="/admin/classes/$cohortId" params={{ cohortId: f.cohort_id }}>{f.name}</Link>
                  </td>
                  <td>{f.members}</td><td>{f.students}</td><td>{f.answered_live}</td><td>{f.practiced_7d}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <div className="flex flex-col gap-2">
          <section className="admin-panel p-2" aria-label="Needs attention">
            <h2 className="admin-label mb-1">Needs attention</h2>
            {h.attention.length === 0 ? <p className="sev-ok">All clear.</p> : null}
            <ul>
              {h.attention.map((a, i) => (
                <li key={i} className={`sev-${a.severity}`}>{a.title}</li>
              ))}
            </ul>
          </section>
          <section className="admin-panel p-2" aria-label="Activity">
            <h2 className="admin-label mb-1">Activity</h2>
            <ol className="max-h-96 overflow-y-auto">
              {(activity.data ?? []).map((r, i) => (
                <li key={`${r.at}-${i}`}>
                  <span className="text-[var(--a-muted)]">{time(r.at)}</span>{' '}
                  <span className={`sev-${r.severity}`}>{r.kind.toUpperCase()}</span>{' '}
                  {r.user_id ? (
                    <Link to="/admin/people/$userId" params={{ userId: r.user_id }}>{r.title}</Link>
                  ) : (
                    <span>{r.title}</span>
                  )}
                </li>
              ))}
            </ol>
          </section>
        </div>
      </div>
    </div>
  )
}
