import { useState, type FormEvent } from 'react'
import {
  inviteLink,
  useDecideFacultyRequest,
  useFacultyRequests,
  useMintFacultyInvite,
  useMyConsoleRole,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

function InviteCard() {
  const mint = useMintFacultyInvite()
  const [recipient, setRecipient] = useState('')
  const [note, setNote] = useState('')
  const [link, setLink] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  const submit = (e: FormEvent) => {
    e.preventDefault()
    setCopied(false)
    mint.mutate(
      { recipientEmail: recipient.trim(), note: note.trim() },
      { onSuccess: code => setLink(inviteLink(code)) },
    )
  }

  return (
    <Card>
      <h2 className="text-sm font-semibold text-slate-900">{S.staffTools.inviteTitle}</h2>
      <p className="mt-1 text-sm text-slate-500">{S.staffTools.inviteHint}</p>
      <form onSubmit={submit} className="mt-3 flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.staffTools.recipient}
          <input type="email" value={recipient} onChange={e => setRecipient(e.target.value)} className={field} />
        </label>
        <label className="text-sm text-slate-700">
          {S.staffTools.note}
          <input maxLength={120} value={note} onChange={e => setNote(e.target.value)} className={field} />
        </label>
        {mint.error ? <Alert tone="error">{mint.error.message}</Alert> : null}
        <div><Button type="submit" disabled={mint.isPending}>{S.staffTools.mint}</Button></div>
      </form>
      {link ? (
        <div className="mt-3 flex items-center gap-2">
          <input readOnly aria-label={S.staffTools.inviteLinkLabel} value={link} className={`${field} mt-0`}
            onFocus={e => e.currentTarget.select()} />
          <Button variant="ghost" onClick={() => {
            void navigator.clipboard?.writeText(link)
            setCopied(true)
          }}>
            {copied ? S.staffTools.copied : S.staffTools.copy}
          </Button>
        </div>
      ) : null}
    </Card>
  )
}

function RequestQueue() {
  const requests = useFacultyRequests(true)
  const decide = useDecideFacultyRequest()
  return (
    <Card>
      <h2 className="mb-2 text-sm font-semibold text-slate-900">{S.staffTools.requestsTitle}</h2>
      {requests.error ? <Alert tone="error">{requests.error.message}</Alert> : null}
      {requests.data && requests.data.length === 0 ? (
        <p className="text-sm text-slate-500">{S.staffTools.noRequests}</p>
      ) : null}
      <ul className="flex flex-col divide-y divide-slate-100">
        {(requests.data ?? []).map(r => (
          <li key={r.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
            <div className="min-w-0">
              <p className="text-sm font-medium text-slate-900">{r.handle}, {r.email}</p>
              <p className="text-xs text-slate-500">
                {r.school}, {r.courses}{r.note ? `. ${r.note}` : ''}
              </p>
            </div>
            <div className="flex gap-2">
              <Button disabled={decide.isPending}
                onClick={() => decide.mutate({ id: r.id, approve: true })}>
                {S.staffTools.approve}
              </Button>
              <Button variant="ghost" disabled={decide.isPending}
                onClick={() => decide.mutate({ id: r.id, approve: false })}>
                {S.staffTools.deny}
              </Button>
            </div>
          </li>
        ))}
      </ul>
    </Card>
  )
}

/** Onboarding tools until the phase 2 admin console replaces them. */
export function StaffTools() {
  const role = useMyConsoleRole()
  if (role.data !== 'staff' && role.data !== 'faculty') return null
  return (
    <div className="mt-6 grid gap-4 lg:grid-cols-2">
      <InviteCard />
      {role.data === 'staff' ? <RequestQueue /> : null}
    </div>
  )
}
