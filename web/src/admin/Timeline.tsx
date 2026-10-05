import type { TimelineEntry } from './adminApi'

const stamp = (iso: string) => {
  const d = new Date(iso)
  return `${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')} ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
}

export function Timeline({ entries }: { entries: TimelineEntry[] }) {
  if (entries.length === 0) return <p className="text-[var(--a-muted)]">Nothing recorded yet.</p>
  return (
    <ol>
      <li className="admin-label mb-1">Timeline · newest first</li>
      {entries.map((e, i) => {
        // The email on a failed sign-in is whatever the person typed, before
        // any account is confirmed to exist: it is not a verified identity.
        const unverifiedEmail = e.kind === 'problem' && e.title.startsWith('signin')
        return (
          <li
            key={`${e.at}-${i}`}
            className={e.severity === 'fail' ? '-mx-2 bg-[#2a1214] px-2' : undefined}
          >
            <span className="text-[var(--a-muted)]">{stamp(e.at)}</span>{' '}
            <span className={`sev-${e.severity}`}>{e.kind.toUpperCase()}</span>{' '}
            <span className={e.severity === 'fail' ? 'sev-fail' : undefined}>{e.title}</span>
            {unverifiedEmail ? (
              <span className="text-[var(--a-muted)]"> (typed email, unverified)</span>
            ) : null}
            {typeof e.detail === 'string' && e.detail ? (
              <span className="text-[var(--a-muted)]"> · {e.detail}</span>
            ) : null}
          </li>
        )
      })}
    </ol>
  )
}
