import { useState } from 'react'
import * as Dialog from '@radix-ui/react-dialog'
import { useClassAnnouncements, useSendAnnouncement } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button } from './ui'
import { daysAgo } from './StudentsTab'

const MAX_LENGTH = 240

function sentMessage(alerted: number | null): string {
  if (alerted === null) return S.message.alertFailed
  if (alerted === 0) return S.message.noDevices
  return S.message.sent(alerted)
}

export function MessageClassDialog({
  cohortId,
  prefill = '',
  open,
  onOpenChange,
}: {
  cohortId: string
  prefill?: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const send = useSendAnnouncement()
  const recent = useClassAnnouncements(cohortId, open)
  const [body, setBody] = useState(prefill)

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-slate-900/40" />
        <Dialog.Content className="fixed left-1/2 top-1/2 max-h-[90vh] w-[min(28rem,90vw)] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-lg bg-white p-4 shadow-lg">
          <Dialog.Title className="text-base font-semibold text-slate-900">
            {S.message.title}
          </Dialog.Title>
          <Dialog.Description className="mt-1 text-sm text-slate-500">
            {S.message.intro}
          </Dialog.Description>
          <label htmlFor="announce-body" className="mt-3 block text-sm font-medium text-slate-700">
            {S.message.label}
          </label>
          <textarea
            id="announce-body"
            rows={4}
            maxLength={MAX_LENGTH}
            value={body}
            onChange={e => setBody(e.target.value)}
            className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900"
          />
          <p className="text-right text-xs text-slate-500">
            {body.length} / {MAX_LENGTH}
          </p>
          {send.error ? <Alert tone="error">{send.error.message}</Alert> : null}
          {send.isSuccess ? (
            <Alert tone={send.data.alerted === null ? 'info' : 'success'}>
              {sentMessage(send.data.alerted)}
            </Alert>
          ) : null}
          <div className="mt-3 flex justify-end gap-2">
            <Dialog.Close asChild>
              <Button variant="ghost">{S.message.close}</Button>
            </Dialog.Close>
            <Button
              disabled={send.isPending || body.trim().length === 0}
              onClick={() =>
                send.mutate(
                  { cohortId, body: body.trim() },
                  { onSuccess: () => setBody('') },
                )
              }
            >
              {S.message.send}
            </Button>
          </div>
          <h3 className="mt-4 border-t border-slate-100 pt-3 text-sm font-semibold text-slate-900">
            {S.message.recent}
          </h3>
          {recent.error ? <Alert tone="error">{recent.error.message}</Alert> : null}
          {recent.data?.length === 0 ? (
            <p className="mt-1 text-sm text-slate-500">{S.message.none}</p>
          ) : null}
          <ul className="mt-1 flex flex-col divide-y divide-slate-100">
            {(recent.data ?? []).map(m => (
              <li key={m.id} className="py-2 text-sm text-slate-700">
                {m.body}
                <span className="block text-xs text-slate-500">
                  {daysAgo(m.created_at)}
                </span>
              </li>
            ))}
          </ul>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
