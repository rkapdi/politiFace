import { secondsLeft, useNow } from '../lib/live'

export function Countdown({
  startedAt,
  questionSeconds,
}: {
  startedAt: string | null | undefined
  questionSeconds: number
}) {
  const now = useNow()
  const left = secondsLeft(startedAt, questionSeconds, now)
  const fraction = questionSeconds === 0 ? 0 : left / questionSeconds
  const r = 26
  const circumference = 2 * Math.PI * r

  return (
    <div className="flex items-center gap-2">
      <svg width="64" height="64" viewBox="0 0 64 64" aria-hidden="true">
        <circle cx="32" cy="32" r={r} fill="none" stroke="#e2e8f0" strokeWidth="6" />
        <circle
          cx="32"
          cy="32"
          r={r}
          fill="none"
          stroke={left <= 5 ? '#dc2626' : '#0f172a'}
          strokeWidth="6"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - fraction)}
          transform="rotate(-90 32 32)"
        />
        <text
          x="32"
          y="37"
          textAnchor="middle"
          fontSize="18"
          fontWeight="600"
          fill="#0f172a"
        >
          {left}
        </text>
      </svg>
      <span aria-live="polite" className="sr-only">
        {left === 10 || left === 5 || left === 0 ? `${left} seconds left` : ''}
      </span>
    </div>
  )
}
