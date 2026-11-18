import { useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'
import type { AdminPicture, AuditRow } from './adminApi'
import { onTrackPct } from './decisions'
import { A, ACTION_WORDS } from './strings'

// One column per day, oldest first, today last. Every lane shares the grid
// so a day lines up from top to bottom.
const grid = 'grid grid-cols-[repeat(14,minmax(0,1fr))] gap-[3px]'
// The label column (w-24) plus the gap beside it: where the day grid starts.
const LABEL_W = 108

type LaneKey = 'answers' | 'live' | 'onTrack' | 'actions'
const LANES: LaneKey[] = ['answers', 'live', 'onTrack', 'actions']
// Opening the console and viewing a person are not actions (as on the server).
const NOT_ACTIONS = new Set(['console_open', 'view_person'])

/** 'YYYY-MM-DD' as a short local date, without a time zone shift. */
function dayLabel(iso: string, weekday = false): string {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d).toLocaleDateString([], {
    ...(weekday ? { weekday: 'short' as const } : {}),
    day: 'numeric',
    month: 'short',
  })
}

/** Staff actions per day, in words, from the audit log (newest 200 rows). */
function actionsByDay(rows: AuditRow[] | undefined, tz: string): Map<string, string> {
  const out = new Map<string, string>()
  if (!rows) return out
  let fmt: Intl.DateTimeFormat
  try {
    fmt = new Intl.DateTimeFormat('en-CA', { timeZone: tz })
  } catch {
    fmt = new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC' })
  }
  const counts = new Map<string, Map<string, number>>()
  for (const r of rows) {
    if (NOT_ACTIONS.has(r.action)) continue
    const day = fmt.format(new Date(r.created_at))
    const byAction = counts.get(day) ?? new Map<string, number>()
    byAction.set(r.action, (byAction.get(r.action) ?? 0) + 1)
    counts.set(day, byAction)
  }
  for (const [day, byAction] of counts) {
    out.set(
      day,
      [...byAction.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([action, n]) => {
          const words = ACTION_WORDS[action] ?? [
            action.replace(/_/g, ' '),
            action.replace(/_/g, ' '),
          ]
          return `${n} ${n === 1 ? words[0] : words[1]}`
        })
        .join(', '),
    )
  }
  return out
}

function Lane({
  laneKey,
  label,
  sub,
  summary,
  active,
  onHover,
  rowRef,
  children,
}: {
  laneKey: LaneKey
  label: string
  sub: string
  /** The lane in one sentence, for screen readers: the marks are decorative. */
  summary: string
  /** The day being read, highlighted in every lane. */
  active: number | null
  onHover: (day: number, lane: LaneKey) => void
  rowRef: (el: HTMLDivElement | null) => void
  children: ReactNode
}) {
  return (
    <div ref={rowRef} className="flex items-center gap-3 border-t border-line py-3.5">
      <div className="w-24 shrink-0">
        <div className="text-[13px] font-bold text-ink">{label}</div>
        <div className="text-[11px] text-ink-3">{sub}</div>
      </div>
      <div className="relative min-w-0 flex-1">
        <div role="img" aria-label={summary}>
          {children}
        </div>
        {/* Hover and tap targets, one per day, over the marks. */}
        <div aria-hidden="true" className={`${grid} absolute -inset-y-2 inset-x-0`}>
          {Array.from({ length: 14 }, (_, i) => (
            <div
              key={i}
              data-day={i}
              data-lane={laneKey}
              onMouseEnter={() => onHover(i, laneKey)}
              onClick={() => onHover(i, laneKey)}
              className={`rounded-[4px] ${active === i ? 'bg-ink/[0.07] ring-1 ring-inset ring-line-strong' : ''}`}
            />
          ))}
        </div>
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
function Bars({ values }: { values: number[] }) {
  const max = Math.max(1, ...values)
  return (
    <div className={`${grid} h-12 items-end`}>
      {values.map((v, i) => (
        <div
          key={i}
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
function Marks({ values, round = false }: { values: number[]; round?: boolean }) {
  return (
    <div className={`${grid} h-6 items-center`}>
      {values.map((v, i) => (
        <div key={i} className="flex h-full items-center justify-center">
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

type DayRow = { lane: LaneKey; label: string; text: string }

/**
 * The last 14 days in four lanes that share one time axis. Hovering or
 * tapping a day, or moving through days with the arrow keys, shows that
 * day across every lane, with what the hovered lane counts.
 */
export function Picture({ picture, audit }: { picture: AdminPicture; audit?: AuditRow[] }) {
  const days = picture.days
  const answers = days.map(d => d.answers)
  const live = days.map(d => d.live_sessions)
  const actions = days.map(d => d.actions)
  const last = days.length - 1
  // Snapshots give the history; the live number is always today's point.
  const onTrack = days.map((d, i) =>
    i === last
      ? onTrackPct(picture.now.on_track, picture.now.students)
      : onTrackPct(d.on_track, d.students),
  )
  const known = onTrack.filter((p): p is number => p != null)
  const actionWords = useMemo(() => actionsByDay(audit, picture.tz), [audit, picture.tz])

  const [day, setDay] = useState<number | null>(null)
  const [lane, setLane] = useState<LaneKey>('answers')
  // How far down the summary sits: measured when the lane changes.
  const [top, setTop] = useState(0)
  const rows = useRef<Partial<Record<LaneKey, HTMLDivElement | null>>>({})
  // Under the top two lanes, over the bottom two.
  const below = LANES.indexOf(lane) < 2
  const pick = (d: number, l: LaneKey) => {
    const row = rows.current[l]
    const under = LANES.indexOf(l) < 2
    if (row) setTop(under ? row.offsetTop + row.offsetHeight + 4 : row.offsetTop - 4)
    setDay(d)
    setLane(l)
  }

  const rowsFor = (i: number): DayRow[] => {
    const d = days[i]
    const today = i === last
    const pctOn = onTrack[i]
    const students = today ? picture.now.students : d.students
    const on = today ? picture.now.on_track : d.on_track
    return [
      {
        lane: 'answers',
        label: A.home.laneAnswers,
        text: A.home.tipAnswers(d.answers, d.practising),
      },
      { lane: 'live', label: A.home.laneLive, text: A.home.tipLive(d.live_sessions) },
      {
        lane: 'onTrack',
        label: A.home.laneOnTrack,
        text:
          pctOn == null || students == null || on == null
            ? A.home.tipOnTrackNone
            : A.home.tipOnTrack(pctOn, on, students),
      },
      {
        lane: 'actions',
        label: A.home.laneActions,
        text: A.home.tipActions(d.actions, actionWords.get(d.day) ?? ''),
      },
    ]
  }
  const title = (i: number) =>
    i === last ? `${A.home.today}, ${dayLabel(days[i].day, true)}` : dayLabel(days[i].day, true)
  const spoken = (i: number) =>
    `${title(i)}. ${rowsFor(i)
      .map(r => `${r.label}: ${r.text}.`)
      .join(' ')}`

  const onKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const d = day ?? last
    const li = LANES.indexOf(lane)
    if (e.key === 'ArrowLeft') pick(Math.max(0, d - 1), lane)
    else if (e.key === 'ArrowRight') pick(Math.min(last, d + 1), lane)
    else if (e.key === 'ArrowUp') pick(d, LANES[Math.max(0, li - 1)])
    else if (e.key === 'ArrowDown') pick(d, LANES[Math.min(LANES.length - 1, li + 1)])
    else if (e.key === 'Home') pick(0, lane)
    else if (e.key === 'End') pick(last, lane)
    else if (e.key === 'Escape') return setDay(null)
    else return
    e.preventDefault()
  }

  // Beside the day, kept inside the card at either end.
  const frac = day == null ? 0 : (day + 0.5) / days.length
  const anchor = day == null ? '' : day < 3 ? 'left' : day > 10 ? 'right' : 'center'

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
      <div
        role="group"
        tabIndex={0}
        aria-label={A.home.pictureKeys}
        aria-describedby={day == null ? undefined : 'picture-day'}
        onKeyDown={onKey}
        onFocus={e => {
          if (e.target === e.currentTarget && day == null) pick(last, lane)
        }}
        onBlur={() => setDay(null)}
        onMouseLeave={() => setDay(null)}
        className="relative rounded-md focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-focus"
      >
        <Lane
          laneKey="answers"
          label={A.home.laneAnswers}
          sub={A.home.laneAnswersSub}
          summary={summarise(A.home.laneAnswers, days, answers)}
          active={day}
          onHover={pick}
          rowRef={el => (rows.current.answers = el)}
        >
          <Bars values={answers} />
        </Lane>
        <Lane
          laneKey="live"
          label={A.home.laneLive}
          sub={A.home.laneLiveSub}
          summary={summarise(A.home.laneLive, days, live)}
          active={day}
          onHover={pick}
          rowRef={el => (rows.current.live = el)}
        >
          <Marks values={live} />
        </Lane>
        <Lane
          laneKey="onTrack"
          label={A.home.laneOnTrack}
          sub={A.home.laneOnTrackSub}
          summary={
            known.length >= 2
              ? A.home.onTrackSummary(known[0], known[known.length - 1], known.length)
              : known.length === 1
                ? A.home.onTrackNoHistory(known[0])
                : A.home.outcomeUnavailable
          }
          active={day}
          onHover={pick}
          rowRef={el => (rows.current.onTrack = el)}
        >
          <OnTrack points={onTrack} />
        </Lane>
        <Lane
          laneKey="actions"
          label={A.home.laneActions}
          sub={A.home.laneActionsSub}
          summary={summarise(A.home.laneActions, days, actions)}
          active={day}
          onHover={pick}
          rowRef={el => (rows.current.actions = el)}
        >
          <Marks values={actions} round />
        </Lane>

        {day != null ? (
          <div
            role="tooltip"
            className={`pointer-events-none absolute z-20 w-[min(300px,100%)] rounded-lg bg-pop p-3 text-left shadow-pop ring-1 ring-line-strong ${
              below ? '' : '-translate-y-full'
            } ${anchor === 'center' ? '-translate-x-1/2' : anchor === 'right' ? '-translate-x-full' : ''}`}
            style={{
              top,
              left:
                anchor === 'left'
                  ? LABEL_W
                  : anchor === 'right'
                    ? '100%'
                    : `calc(${LABEL_W}px + (100% - ${LABEL_W}px) * ${frac})`,
            }}
          >
            <div className="text-[12.5px] font-bold text-ink">{title(day)}</div>
            <dl className="mt-1.5 flex flex-col gap-1">
              {rowsFor(day).map(r => (
                <div
                  key={r.lane}
                  className="grid grid-cols-[88px_minmax(0,1fr)] gap-2 text-[12px] leading-[16px]"
                >
                  <dt className={r.lane === lane ? 'font-bold text-ink' : 'text-ink-3'}>
                    {r.label}
                  </dt>
                  <dd className={r.lane === lane ? 'font-semibold text-ink' : 'text-ink-2'}>
                    {r.text}
                  </dd>
                </div>
              ))}
            </dl>
            <p className="mt-2 border-t border-line pt-2 text-[11.5px] leading-[16px] text-ink-3">
              {A.home.laneHelp[lane]}
            </p>
          </div>
        ) : null}
        {/* Read aloud as the day changes, for keyboard and screen reader use. */}
        <p id="picture-day" className="sr-only" aria-live="polite">
          {day == null ? '' : spoken(day)}
        </p>
      </div>
    </div>
  )
}
