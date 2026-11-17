import type { CohortPulse, PulseCardData } from '../lib/api'
import { S } from '../lib/strings'
import { Button, Card } from './ui'

const ACTION_LABEL: Record<PulseCardData['kind'], string> = {
  at_risk: S.pulse.seeWho,
  weak_domain: S.pulse.reteach,
  participation: S.pulse.message,
}

/** The week in one sentence, then what to do about it. */
export function PulseBanner({
  pulse,
  onAction,
}: {
  pulse: CohortPulse
  onAction: (card: PulseCardData) => void
}) {
  return (
    <Card className="flex h-full flex-col justify-between gap-5">
      <div>
        <h2 className="sr-only">Class pulse</h2>
        <p aria-hidden="true" className="mb-2 text-[13px] font-semibold text-ink-3">
          {S.pulse.label}
        </p>
        <p className="text-pretty text-[21px] font-semibold leading-[1.4] tracking-[-0.02em] text-ink">
          {pulse.sentence}
        </p>
      </div>
      {pulse.cards.length > 0 ? (
        <ul className="grid gap-2 sm:grid-cols-3">
          {pulse.cards.map(c => (
            <li
              key={c.kind}
              className="flex flex-col items-start justify-between gap-3 rounded-lg bg-raised p-3.5"
            >
              <div>
                <p className="text-sm font-semibold text-ink">{c.headline}</p>
                <p className="mt-1 text-xs text-ink-3">{c.detail}</p>
              </div>
              <Button variant="ghost" className="px-3 py-1.5 text-xs" onClick={() => onAction(c)}>
                {ACTION_LABEL[c.kind]}
              </Button>
            </li>
          ))}
        </ul>
      ) : null}
    </Card>
  )
}
