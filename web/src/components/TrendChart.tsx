import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { axisLine, axisTick, tooltipStyle } from './chartTheme'
import type { TrendRow } from '../lib/api'

export function TrendChart({ rows }: { rows: TrendRow[] }) {
  return (
    <figure>
      <figcaption className="mb-2 text-sm font-medium text-ink-2">
        Practice over the last {rows.length} days
      </figcaption>
      <div className="h-48" aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={rows} margin={{ top: 4, right: 8, bottom: 0, left: -18 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--color-line-strong)" />
            <XAxis
              dataKey="day"
              tick={axisTick(11)} {...axisLine}
              tickFormatter={(d: string) => d.slice(5)}
            />
            <YAxis tick={axisTick(11)} {...axisLine} allowDecimals={false} />
            <Tooltip {...tooltipStyle} />
            <Area
              type="monotone"
              dataKey="answers"
              name="Answers"
              stroke="var(--color-ink)"
              fill="var(--color-chart-neutral)"
            />
            <Area
              type="monotone"
              dataKey="active_students"
              name="Active students"
              stroke="var(--color-pass)"
              fill="var(--color-pass-soft)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
      <table className="sr-only">
        <caption>Daily practice: answers and active students</caption>
        <thead>
          <tr>
            <th scope="col">Day</th>
            <th scope="col">Answers</th>
            <th scope="col">Active students</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(r => (
            <tr key={r.day}>
              <td>{r.day}</td>
              <td>{r.answers}</td>
              <td>{r.active_students}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}
