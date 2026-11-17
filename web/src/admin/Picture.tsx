import type { ReactNode } from 'react'
import type { AdminPicture } from './adminApi'
import { onTrackPct } from './decisions'
import { A } from './strings'

// One column per day, oldest first, today last. Every lane shares the grid
// so a day lines up from top to bottom.
const grid = 'grid grid-cols-[repeat(14,minmax(0,1fr))] gap-[3px]'

/** 'YYYY-MM-DD' as a short local date, without a time zone shift. */
function dayLabel(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d).toLocaleDateString([], { day: 'numeric', month: 'short' })
}

function Lane({
  label,
  sub,
  summary,
  children,
}: {
  label: string
  sub: string
  /** The lane in one sentence, for screen readers: the marks are decorative. */
  summary: string
  children: ReactNode
}) {
  return (
    <div className="flex items-center gap-3 border-t border-line py-3.5">
      <div className="w-24 shrink-0">
        <div className="text-[13px] font-bold text-ink">{label}</div>
        <div className="text-[11px] text-ink-3">{sub}</div>
      </div>
      <div role="img" aria-label={summary} className="min-w-0 flex-1">
        {children}
      </div>
    </div>
  )
}

function summarise(label: string, days: { day: string }[], values: number[]): string {
  const total = values.reduce((a, b) => a + b, 0)
  const peak = Math.max(...values)
  return A.home.laneSummary(label, total, peak, dayLabel(days[values.indexOf(peak)].day))
}

/** Bars scaled to the busiest day. Today is the accent bar. */
function Bars({ days, values, unit }: { days: { day: string }[]; values: number[]; unit: string }) {
  const max = Math.max(1, ...values)
  return (
    <div className={`${grid} h-12 items-end`}>
      {values.map((v, i) => (
        <div
          key={days[i].day}
          title={A.home.dayValue(dayLabel(days[i].day), v, unit)}
          className={`rounded-[3px] ${
            v === 0 ? 'bg-chart-neutral' : i === values.length - 1 ? 'bg-accent' : 'bg-bar'
          }`}
          style={{ height: v === 0 ? 2 : `${Math.max(8, (v / max) * 100)}%` }}
        />
      ))}
    </div>
  )
}

/** One mark per day that had any, with the count inside when above one. */
function Marks({
  days,
  values,
  unit,
  round = false,
}: {
  days: { day: string }[]
  values: number[]
  unit: string
  round?: boolean
}) {
  return (
    <div className={`${grid} h-6 items-center`}>
      {values.map((v, i) => (
        <div
          key={days[i].day}
          title={A.home.dayValue(dayLabel(days[i].day), v, unit)}
          className="flex h-full items-center justify-center"
        >
          {v === 0 ? (
            <span className="h-[2px] w-full rounded-full bg-chart-neutral" />
          ) : (
            <span
              className={`flex h-5 items-center justify-center text-[11px] font-bold tabular-nums ${
                round
                  ? 'w-5 max-w-full rounded-full bg-strong text-on-strong'
                  : 'w-full rounded-[5px] bg-accent text-on-accent'
              }`}
            >
              {v > 1 ? v : ''}
            </span>
          )}
        </div>
      ))}
    </div>
  )
}

/** The outcome number over time. Needs two points before it is a line. */
function OnTrack({ points }: { points: (number | null)[] }) {
  const known = points
    .map((p, i) => ({ p, i }))
    .filter((x): x is { p: number; i: number } => x.p != null)
  const last = known[known.length - 1]
  if (!last) return <p className="text-xs text-ink-3">{A.home.outcomeUnavailable}</p>
  if (known.length < 2) {
    return <p className="text-xs text-ink-2">{A.home.onTrackNoHistory(last.p)}</p>
  }
  const lo = Math.max(0, Math.min(...known.map(k => k.p)) - 6)
  const hi = Math.min(100, Math.max(...known.map(k => k.p)) + 6)
  const x = (i: number) => ((i + 0.5) / points.length) * 100
  const y = (p: number) => 100 - ((p - lo) / (hi - lo)) * 100
  const first = known[0]
  return (
    <div className="relative h-14">
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        className="absolute inset-0 size-full overflow-visible"
        aria-hidden="true"
      >
        <polyline
          points={known.map(k => `${x(k.i)},${y(k.p)}`).join(' ')}
          fill="none"
          stroke="var(--color-bar)"
          strokeWidth="2"
          strokeLinejoin="round"
          vectorEffect="non-scaling-stroke"
        />
      </svg>
      <span
        className="absolute size-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-accent ring-2 ring-panel"
        style={{ left: `${x(last.i)}%`, top: `${y(last.p)}%` }}
      />
      <span
        className="absolute -translate-y-full pb-1 text-[11px] font-semibold tabular-nums text-ink-3"
        style={{ left: `${x(first.i)}%`, top: `${y(first.p)}%` }}
      >
        {first.p}%
      </span>
      <span
        className="absolute right-0 -translate-y-full pb-2 text-xs font-extrabold tabular-nums text-ink"
        style={{ top: `${y(last.p)}%` }}
      >
        {last.p}%
      </span>
    </div>
  )
}

/** The last 14 days in four lanes that share one time axis. */
export function Picture({ picture }: { picture: AdminPicture }) {
  const days = picture.days
  const answers = days.map(d => d.answers)
  const live = days.map(d => d.live_sessions)
  const actions = days.map(d => d.actions)
  // Snapshots give the history; the live number is always today's point.
  const onTrack = days.map((d, i) =>
    i === days.length - 1
      ? onTrackPct(picture.now.on_track, picture.now.students)
      : onTrackPct(d.on_track, d.students),
  )
  const known = onTrack.filter((p): p is number => p != null)
  return (
    <div>
      <div className="flex items-center gap-3 pb-2">
        <div className="w-24 shrink-0" />
        <div className={`${grid} min-w-0 flex-1 font-mono text-[10.5px] text-ink-3`}>
          <span className="col-start-1 whitespace-nowrap">{dayLabel(days[0].day)}</span>
          <span className="col-start-8 whitespace-nowrap">{dayLabel(days[7].day)}</span>
          <span className="col-start-14 justify-self-end whitespace-nowrap font-bold text-ink">
            {A.home.today}
          </span>
        </div>
      </div>
      <Lane
        label={A.home.laneAnswers}
        sub={A.home.laneAnswersSub}
        summary={summarise(A.home.laneAnswers, days, answers)}
      >
        <Bars days={days} values={answers} unit={A.home.unitAnswers} />
      </Lane>
      <Lane
        label={A.home.laneLive}
        sub={A.home.laneLiveSub}
        summary={summarise(A.home.laneLive, days, live)}
      >
        <Marks days={days} values={live} unit={A.home.unitSessions} />
      </Lane>
      <Lane
        label={A.home.laneOnTrack}
        sub={A.home.laneOnTrackSub}
        summary={
          known.length >= 2
            ? A.home.onTrackSummary(known[0], known[known.length - 1], known.length)
            : known.length === 1
              ? A.home.onTrackNoHistory(known[0])
              : A.home.outcomeUnavailable
        }
      >
        <OnTrack points={onTrack} />
      </Lane>
      <Lane
        label={A.home.laneActions}
        sub={A.home.laneActionsSub}
        summary={summarise(A.home.laneActions, days, actions)}
      >
        <Marks days={days} values={actions} unit={A.home.unitActions} round />
      </Lane>
    </div>
  )
}
