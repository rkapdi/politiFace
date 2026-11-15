import { Badge } from './ui'

export type DomainBar = {
  label: string
  value: number | null // 0..1
  detail?: string
  metric?: string // word used in the aria label, default 'accuracy'
}

const PASS = 60

// A domain under the pass line is drawn hollow and tagged in words, so it
// never reads by colour alone. The tick on every bar is the pass line.
export function DomainBars({ bars }: { bars: DomainBar[] }) {
  return (
    <ul className="flex flex-col gap-4">
      {bars.map(b => {
        const pct = b.value === null ? null : Math.round(b.value * 100)
        const below = pct !== null && pct < PASS
        return (
          <li key={b.label}>
            <div className="mb-1.5 flex items-baseline justify-between gap-2 text-sm">
              <span className={`flex flex-wrap items-center gap-2 text-ink ${below ? 'font-bold' : 'font-medium'}`}>
                {b.label}
                {below ? <Badge tone="red">below pass</Badge> : null}
              </span>
              <span className={`whitespace-nowrap tabular-nums ${below ? 'font-bold text-risk' : 'text-ink-2'}`}>
                {pct === null ? 'No data yet' : `${pct}%`}
                {b.detail ? ` · ${b.detail}` : ''}
              </span>
            </div>
            <div
              role="img"
              aria-label={
                pct === null
                  ? `${b.label}, no data yet`
                  : `${b.label}, ${pct} percent ${b.metric ?? 'accuracy'}`
              }
              className="relative h-2.5 rounded-full bg-control"
            >
              <div
                className={`h-2.5 rounded-full ${
                  pct === null ? '' : below ? 'border-2 border-risk bg-panel' : 'bg-bar'
                }`}
                style={{ width: `${pct ?? 0}%` }}
              />
              <span
                aria-hidden="true"
                className="absolute -top-0.5 h-3.5 w-0.5 bg-pass ring-2 ring-panel"
                style={{ left: `${PASS}%` }}
              />
            </div>
          </li>
        )
      })}
    </ul>
  )
}
