import { useState, type ReactNode } from 'react'
import { Copy, Send } from 'lucide-react'
import { useCohortInfo } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button } from './ui'

/** Class name, the join code the professor hands out, the tabs and the main actions. */
export function ClassHeader({
  cohortId,
  tabs,
  onMessage,
  onStartLive,
}: {
  cohortId: string
  tabs?: ReactNode
  onMessage?: () => void
  onStartLive?: () => void
}) {
  const info = useCohortInfo(cohortId)
  const [copied, setCopied] = useState(false)

  if (info.error) return <Alert tone="error">{info.error.message}</Alert>
  if (!info.data) return tabs ? <div className="px-2">{tabs}</div> : null
  const { name, term, join_code: code } = info.data

  const copy = () => {
    void navigator.clipboard?.writeText(code)
    setCopied(true)
  }

  return (
    <header className="flex flex-col gap-3 px-2">
      <div className="flex min-h-[52px] flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-[28px] font-bold leading-tight tracking-[-0.03em] text-ink">{name}</h1>
          {term ? <Badge>{term}</Badge> : null}
        </div>
        <div className="flex flex-wrap items-center gap-2.5">
          {onMessage ? (
            <Button variant="ghost" className="bg-panel" onClick={onMessage}>
              <Send aria-hidden="true" className="size-4" />
              {S.message.open}
            </Button>
          ) : null}
          {onStartLive ? <Button onClick={onStartLive}>{S.live.start}</Button> : null}
        </div>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        {tabs}
        <div className="flex items-center gap-2.5 rounded-full bg-panel py-1 pl-4 pr-1" title={S.classCode.hint}>
          <span className="text-xs font-semibold text-ink-3">{S.classCode.label}</span>
          <span className="text-base font-bold tracking-[0.14em] text-ink">{code}</span>
          <Button variant="ghost" className="px-3 py-1.5 text-xs" onClick={copy}>
            <Copy aria-hidden="true" className="size-3.5" />
            {copied ? S.classCode.copied : S.classCode.copy}
          </Button>
        </div>
      </div>
    </header>
  )
}
