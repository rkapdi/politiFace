import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { StudentTrend } from '../lib/api'

export function StudentTrendChart({ trend }: { trend: StudentTrend }) {
  const rows = trend.weeks.map(w => ({
    week: w.week_start.slice(5),
    projected: w.projected,
    answers: w.answers,
  }))

  return (
    <figure>
      <figcaption className="mb-2 text-sm font-medium text-slate-700">
        Projected score by week, pass line {trend.pass_line}
      </figcaption>
      <div className="h-40" aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={rows} margin={{ top: 4, right: 8, bottom: 0, left: -24 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey="week" tick={{ fontSize: 10 }} />
            <YAxis domain={[0, 80]} tick={{ fontSize: 11 }} />
            <Tooltip />
            <ReferenceLine
              y={trend.pass_line}
              stroke="var(--color-risk)"
              strokeDasharray="4 4"
            />
            <Line
              type="monotone"
              dataKey="projected"
              name="Projected of 80"
              stroke="var(--color-ink)"
              strokeWidth={2}
              dot={{ r: 3 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <table className="sr-only">
        <caption>
          Weekly projected score of 80; the pass line is {trend.pass_line}
        </caption>
        <thead>
          <tr>
            <th scope="col">Week</th>
            <th scope="col">Projected</th>
            <th scope="col">Answers</th>
          </tr>
        </thead>
        <tbody>
          {trend.weeks.map(w => (
            <tr key={w.week_start}>
              <td>{w.week_start}</td>
              <td>{w.projected ?? ''}</td>
              <td>{w.answers}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}
