import { S } from '../lib/strings'

// Class percent correct on one question against the instructor's target.
// The sentence carries the meaning; the bar and its target tick are
// decoration (aria-hidden), so nothing depends on colour alone. Copy never
// shames: below target reads as the number and the goal, not a failure.
export function GoalMeter({
  goalPct,
  classPct,
}: {
  goalPct: number
  classPct: number | null
}) {
  const met = classPct !== null && classPct >= goalPct
  const headline =
    classPct === null
      ? S.live.goalNoAnswers
      : met
        ? S.live.goalMet(classPct)
        : S.live.goalNotYet(classPct)
  return (
    <section
      aria-label={S.live.goalTitle}
      className="rounded-md border border-slate-200 p-3"
    >
      <h3 className="text-xs font-semibold uppercase tracking-wide text-slate-500">
        {S.live.goalTitle}
      </h3>
      <p className="mt-1 flex justify-between gap-3 text-sm">
        <span className="font-semibold text-slate-900">{headline}</span>
        <span className="text-slate-600">{S.live.goalTarget(goalPct)}</span>
      </p>
      <div aria-hidden="true" className="relative mt-2 h-3">
        <div className="absolute inset-x-0 top-1 h-1.5 rounded-full bg-slate-200" />
        <div
          className="absolute left-0 top-1 h-1.5 rounded-full bg-slate-800"
          style={{ width: `${classPct ?? 0}%` }}
        />
        <div
          className="absolute top-0 h-3 w-0.5 bg-slate-500"
          style={{ left: `calc(${goalPct}% - 1px)` }}
        />
      </div>
    </section>
  )
}
