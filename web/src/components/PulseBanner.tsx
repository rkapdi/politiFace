import type { CohortPulse, PulseCardData } from '../lib/api'
import { Button, Card } from './ui'

const ACTION_LABEL: Record<PulseCardData['kind'], string> = {
  at_risk: 'See who',
  weak_domain: 'Run a reteach session',
  participation: 'Message the class',
}

export function PulseBanner({
  pulse,
  onAction,
}: {
  pulse: CohortPulse
  onAction: (kind: PulseCardData['kind']) => void
}) {
  return (
    <Card>
      <h2 className="sr-only">Class pulse</h2>
      <p className="text-base font-medium leading-relaxed text-slate-900">
        {pulse.sentence}
      </p>
      {pulse.cards.length > 0 ? (
        <ul className="mt-3 grid gap-2 sm:grid-cols-3">
          {pulse.cards.map(c => (
            <li
              key={c.kind}
              className="flex flex-col justify-between gap-2 rounded-md bg-slate-50 p-3"
            >
              <div>
                <p className="text-sm font-semibold text-slate-900">
                  {c.headline}
                </p>
                <p className="mt-1 text-xs text-slate-500">{c.detail}</p>
              </div>
              <Button variant="ghost" onClick={() => onAction(c.kind)}>
                {ACTION_LABEL[c.kind]}
              </Button>
            </li>
          ))}
        </ul>
      ) : null}
    </Card>
  )
}
