import type { LucideIcon } from 'lucide-react'
import { Button } from './ui'

/** Designed empty state: icon, one sentence, one clear next action. */
export function EmptyState({
  icon: Icon,
  title,
  hint,
  actionLabel,
  onAction,
}: {
  icon: LucideIcon
  title: string
  hint: string
  actionLabel?: string
  onAction?: () => void
}) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-line bg-white px-6 py-10 text-center">
      <Icon aria-hidden="true" className="size-8 text-muted" strokeWidth={1.5} />
      <p className="text-sm font-semibold text-ink">{title}</p>
      <p className="max-w-sm text-sm text-muted">{hint}</p>
      {actionLabel && onAction ? (
        <div className="mt-2">
          <Button variant="ghost" onClick={onAction}>
            {actionLabel}
          </Button>
        </div>
      ) : null}
    </div>
  )
}
