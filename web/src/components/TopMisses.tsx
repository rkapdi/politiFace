import type { TopMissRow } from '../lib/api'

export function TopMisses({ rows }: { rows: TopMissRow[] }) {
  if (rows.length === 0) {
    return (
      <p className="text-sm text-slate-500">
        No questions clear the 5-student reporting floor yet.
      </p>
    )
  }
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <caption className="sr-only">Most missed questions</caption>
        <thead>
          <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
            <th scope="col" className="py-2 pr-3 font-medium">Question</th>
            <th scope="col" className="py-2 pr-3 font-medium">Domain</th>
            <th scope="col" className="py-2 pr-3 font-medium">Students</th>
            <th scope="col" className="py-2 font-medium">Miss rate</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(r => (
            <tr key={r.question_id} className="border-b border-slate-100">
              <td className="max-w-md truncate py-2 pr-3" title={r.stem}>
                {r.stem}
              </td>
              <td className="py-2 pr-3">{r.domain_code}</td>
              <td className="py-2 pr-3">{r.students}</td>
              <td className="py-2 font-medium text-red-700">
                {Math.round(r.miss_rate * 100)}%
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
