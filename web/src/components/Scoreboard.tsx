import type { ScoreboardRow } from '../lib/api'

export function Scoreboard({ rows }: { rows: ScoreboardRow[] }) {
  if (rows.length === 0) {
    return <p className="text-sm text-slate-500">No answers yet.</p>
  }
  return (
    <ol className="flex flex-col gap-1">
      {rows.map(r => (
        <li
          key={`${r.rank}-${r.handle}`}
          className={`flex items-center justify-between rounded-md px-3 py-1.5 text-sm ${
            r.is_me ? 'bg-slate-900 text-white' : 'bg-slate-50 text-slate-800'
          } ${r.rank <= 3 ? 'font-semibold' : ''}`}
        >
          <span>
            <span className="mr-2 inline-block w-6 text-right tabular-nums">
              {r.rank}.
            </span>
            {r.handle}
          </span>
          <span className="tabular-nums">
            {r.score} pts · {r.correct_count} correct
          </span>
        </li>
      ))}
    </ol>
  )
}
