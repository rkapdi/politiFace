import { useState } from 'react'
import { Link } from '@tanstack/react-router'
import { useAdminAudit } from './adminApi'
import { A, AUDIT_ACTIONS } from './strings'

export function AuditPage() {
  const [action, setAction] = useState('')
  const audit = useAdminAudit(action || undefined)
  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.audit}</h1>
      <label className="flex items-center gap-2">
        <span className="admin-label">{A.audit.filterLabel}</span>
        <select
          value={action}
          onChange={e => setAction(e.target.value)}
          className="border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]"
        >
          <option value="">{A.audit.filterAll}</option>
          {AUDIT_ACTIONS.map(a => (
            <option key={a} value={a}>{a.replace(/_/g, ' ')}</option>
          ))}
        </select>
      </label>
      <table className="admin-panel w-full">
        <thead>
          <tr className="admin-label text-left">
            <th scope="col" className="p-1">{A.audit.colWhen}</th><th scope="col">{A.audit.colWho}</th>
            <th scope="col">{A.audit.colAction}</th><th scope="col">{A.audit.colTarget}</th>
          </tr>
        </thead>
        <tbody>
          {(audit.data ?? []).map(a => (
            <tr key={a.id} className="border-t border-[var(--a-line)]">
              <td className="p-1 text-[var(--a-muted)]">{a.created_at.replace('T', ' ').slice(0, 16)}</td>
              <td>{a.actor_handle ?? A.audit.unknownActor}</td>
              <td>{a.action.replace(/_/g, ' ')}</td>
              <td>
                {a.target_user ? (
                  <Link to="/admin/people/$userId" params={{ userId: a.target_user }}>{a.target_label ?? A.audit.fallbackPerson}</Link>
                ) : a.target_cohort ? (
                  <Link to="/admin/classes/$cohortId" params={{ cohortId: a.target_cohort }}>{a.target_label ?? A.audit.fallbackClass}</Link>
                ) : a.target_session ? (
                  <Link to="/admin/sessions/$sessionId" params={{ sessionId: a.target_session }}>{a.target_label ?? A.audit.fallbackSession}</Link>
                ) : (
                  <span className="text-[var(--a-muted)]">{A.audit.noTarget}</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
