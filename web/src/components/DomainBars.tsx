export type DomainBar = {
  label: string
  value: number | null // 0..1
  detail?: string
  metric?: string // word used in the aria label, default 'accuracy'
}

export function DomainBars({ bars }: { bars: DomainBar[] }) {
  return (
    <ul className="flex flex-col gap-3">
      {bars.map(b => {
        const pct = b.value === null ? null : Math.round(b.value * 100)
        return (
          <li key={b.label}>
            <div className="mb-1 flex items-baseline justify-between text-sm">
              <span className="font-medium text-slate-700">{b.label}</span>
              <span className="text-slate-500">
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
              className="h-2 rounded-full bg-slate-100"
            >
              <div
                className={`h-2 rounded-full ${
                  pct === null
                    ? ''
                    : pct >= 60
                      ? 'bg-green-600'
                      : 'bg-amber-500'
                }`}
                style={{ width: `${pct ?? 0}%` }}
              />
            </div>
          </li>
        )
      })}
    </ul>
  )
}
