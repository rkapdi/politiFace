import { useState, type FormEvent } from 'react'
import {
  inviteLink,
  useAmVerifiedFaculty,
  useMintFacultyInvite,
  useMyConsoleRole,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

function InviteForm() {
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

/**
 * For verified instructors. Staff invite from the console instead. Console
 * role 'faculty' also covers unverified co-faculty (added by a verified
 * professor but who has not redeemed their own invite yet), who cannot mint,
 * so this gates on actual verification, not just the role.
 */
export function InviteColleague() {
  const role = useMyConsoleRole()
  const verified = useAmVerifiedFaculty(role.data === 'faculty')
  const [open, setOpen] = useState(false)
  if (role.data !== 'faculty' || verified.data !== true) return null
  return (
    <div className="mt-6">
      {open ? (
        <InviteForm />
      ) : (
        <Button variant="ghost" aria-expanded={false} onClick={() => setOpen(true)}>
          {S.staffTools.inviteOpen}
        </Button>
      )}
    </div>
  )
}
