import { useState } from 'react'
import { useCohortInfo } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card } from './ui'

/** Class name plus the join code the professor hands out to students. */
export function ClassHeader({ cohortId }: { cohortId: string }) {
  const info = useCohortInfo(cohortId)
  const [copied, setCopied] = useState(false)

  if (info.error) return <Alert tone="error">{info.error.message}</Alert>
  if (!info.data) return null
  const { name, term, join_code: code } = info.data

  const copy = () => {
    void navigator.clipboard?.writeText(code)
    setCopied(true)
  }

  return (
    <Card className="flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">{name}</h1>
        {term ? (
          <div className="mt-1">
            <Badge>{term}</Badge>
          </div>
        ) : null}
      </div>
      <div className="text-right">
        <p className="text-xs font-medium uppercase tracking-wide text-slate-500">
          {S.classCode.label}
        </p>
        <div className="flex items-center justify-end gap-2">
          <p className="text-3xl font-bold tracking-[0.3em] text-slate-900">
            {code}
          </p>
          <Button variant="ghost" onClick={copy}>
            {copied ? S.classCode.copied : S.classCode.copy}
          </Button>
        </div>
        <p className="mt-1 max-w-xs text-xs text-slate-500">{S.classCode.hint}</p>
      </div>
    </Card>
  )
}
