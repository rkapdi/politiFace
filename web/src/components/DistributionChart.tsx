import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { CohortDistribution } from '../lib/api'

const BIN_ORDER = [
  '0-9',
  '10-19',
  '20-29',
  '30-39',
  '40-49',
  '50-59',
  '60-69',
  '70-80',
]

// The pass line (48) falls inside the 40-49 bin: bins fully below it read
// as risk, the straddling bin as borderline, bins above as clear.
function binColor(bin: string): string {
  const lower = Number(bin.split('-')[0])
  if (lower >= 50) return '#16a34a'
  if (lower >= 40) return '#d97706'
  return '#dc2626'
}

export function DistributionChart({
  distribution,
}: {
  distribution: CohortDistribution
}) {
  const rows = BIN_ORDER.map(bin => ({
    bin,
    students: distribution.bins?.[bin] ?? 0,
  }))

  return (
    <figure>
      <figcaption className="mb-2 flex items-baseline justify-between text-sm">
        <span className="font-medium text-slate-700">
          Projected scores, pass line {distribution.pass_line}
        </span>
        {distribution.avg !== undefined ? (
          <span className="text-slate-500">
            class average {Math.round(distribution.avg)} of 80
          </span>
        ) : null}
      </figcaption>
      <div className="h-44" aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={rows} margin={{ top: 4, right: 8, bottom: 0, left: -24 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" vertical={false} />
            <XAxis dataKey="bin" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
            <Tooltip />
            <Bar dataKey="students" name="Students">
              {rows.map(r => (
                <Cell key={r.bin} fill={binColor(r.bin)} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
      <table className="sr-only">
        <caption>
          Students by projected score band; the pass line is {distribution.pass_line}
        </caption>
        <thead>
          <tr>
            <th scope="col">Score band</th>
            <th scope="col">Students</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(r => (
            <tr key={r.bin}>
              <td>{r.bin}</td>
              <td>{r.students}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}
