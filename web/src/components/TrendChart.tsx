import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { TrendRow } from '../lib/api'

export function TrendChart({ rows }: { rows: TrendRow[] }) {
  return (
    <figure>
      <figcaption className="mb-2 text-sm font-medium text-slate-700">
        Practice over the last {rows.length} days
      </figcaption>
      <div className="h-48" aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={rows} margin={{ top: 4, right: 8, bottom: 0, left: -18 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis
              dataKey="day"
              tick={{ fontSize: 11 }}
              tickFormatter={(d: string) => d.slice(5)}
            />
            <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
            <Tooltip />
            <Area
              type="monotone"
              dataKey="answers"
              name="Answers"
              stroke="#0f172a"
              fill="#cbd5e1"
            />
            <Area
              type="monotone"
              dataKey="active_students"
              name="Active students"
              stroke="#16a34a"
              fill="#bbf7d0"
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
