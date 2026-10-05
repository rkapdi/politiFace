import { Link } from '@tanstack/react-router'
import { useAdminAudit } from './adminApi'
import { A } from './strings'

export function AuditPage() {
  const audit = useAdminAudit()
  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.audit}</h1>
      <table className="admin-panel w-full">
        <thead>
          <tr className="admin-label text-left">
            <th scope="col" className="p-1">When</th><th scope="col">Who</th>
            <th scope="col">Action</th><th scope="col">Target</th>
          </tr>
        </thead>
        <tbody>
          {(audit.data ?? []).map(a => (
            <tr key={a.id} className="border-t border-[var(--a-line)]">
              <td className="p-1 text-[var(--a-muted)]">{a.created_at.replace('T', ' ').slice(0, 16)}</td>
              <td>{a.actor_handle ?? 'unknown'}</td>
              <td>{a.action.replace(/_/g, ' ')}</td>
              <td>
                {a.target_user ? (
                  <Link to="/admin/people/$userId" params={{ userId: a.target_user }}>{a.target_label ?? 'person'}</Link>
                ) : a.target_cohort ? (
                  <Link to="/admin/classes/$cohortId" params={{ cohortId: a.target_cohort }}>{a.target_label ?? 'class'}</Link>
                ) : a.target_session ? (
                  <Link to="/admin/sessions/$sessionId" params={{ sessionId: a.target_session }}>{a.target_label ?? 'session'}</Link>
                ) : (
                  <span className="text-[var(--a-muted)]">console</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
