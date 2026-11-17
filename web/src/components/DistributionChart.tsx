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
import { axisLine, axisTick, tooltipStyle } from './chartTheme'
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

// The pass line (48) falls inside the 40-49 bin. Bins above it are solid,
// the straddling bin is muted, and bins fully below it are hollow with a
// risk outline, so the three bands differ by fill and not only by colour.
function binMark(bin: string): { fill: string; stroke?: string; strokeWidth?: number } {
  const lower = Number(bin.split('-')[0])
  if (lower >= 50) return { fill: 'var(--color-bar)' }
  if (lower >= 40) return { fill: 'var(--color-chart-neutral)' }
  return { fill: 'transparent', stroke: 'var(--color-risk)', strokeWidth: 2 }
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
        <span className="font-medium text-ink-2">
          Projected scores, pass line {distribution.pass_line}
        </span>
        {distribution.avg !== undefined ? (
          <span className="text-ink-3">
            class average {Math.round(distribution.avg)} of 80
          </span>
        ) : null}
      </figcaption>
      <div className="h-44" aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={rows} margin={{ top: 4, right: 8, bottom: 0, left: -24 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--color-line-strong)" vertical={false} />
            <XAxis dataKey="bin" tick={axisTick(10)} {...axisLine} />
            <YAxis tick={axisTick(11)} {...axisLine} allowDecimals={false} />
            <Tooltip {...tooltipStyle} />
            <Bar dataKey="students" name="Students" radius={[5, 5, 0, 0]}>
              {rows.map(r => (
                <Cell key={r.bin} {...binMark(r.bin)} />
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
