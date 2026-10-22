import { isUnverifiedSignin, type TimelineEntry } from './adminApi'
import { formatDetailObject } from './formatDetail'
import { A } from './strings'

const stamp = (iso: string) => {
  const d = new Date(iso)
  return `${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getDate().toString().padStart(2, '0')} ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`
}

export function Timeline({ entries }: { entries: TimelineEntry[] }) {
  return (
    <>
      <div className="admin-label mb-1">{A.timeline.header}</div>
      {entries.length === 0 ? (
        <p className="text-[var(--a-muted)]">{A.timeline.empty}</p>
      ) : (
        <ol>
          {entries.map((e, i) => {
            const unverifiedEmail = isUnverifiedSignin(e.kind, e.title)
            const detailText =
              typeof e.detail === 'string' && e.detail ? e.detail : formatDetailObject(e.detail)
            return (
              <li
                key={`${e.at}-${i}`}
                className={e.severity === 'fail' ? '-mx-2 bg-[#2a1214] px-2' : undefined}
              >
                <span className="text-[var(--a-muted)]">{stamp(e.at)}</span>{' '}
                <span className={`sev-${e.severity}`}>{e.kind.toUpperCase()}</span>{' '}
                <span className={e.severity === 'fail' ? 'sev-fail' : undefined}>{e.title}</span>
                {unverifiedEmail ? (
                  <span className="text-[var(--a-muted)]"> {A.timeline.unverifiedEmail}</span>
                ) : null}
                {detailText ? (
                  <span className="text-[var(--a-muted)]"> · {detailText}</span>
                ) : null}
              </li>
            )
          })}
        </ol>
      )}
    </>
  )
}
