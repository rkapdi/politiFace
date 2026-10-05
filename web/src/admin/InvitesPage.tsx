import { useEffect, useRef, useState, type FormEvent } from 'react'
import { inviteLink } from '../lib/api'
import { useAdminInvites, useMintInvite, useRevokeInvite } from './adminApi'
import { A } from './strings'

const tone: Record<string, string> = {
  active: 'sev-ok',
  used: 'text-[var(--a-muted)]',
  expired: 'sev-warn',
  revoked: 'sev-fail',
}

export function InvitesPage() {
  const invites = useAdminInvites()
  const mint = useMintInvite()
  const revoke = useRevokeInvite()
  const [email, setEmail] = useState('')
  const [note, setNote] = useState('')
  const [link, setLink] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
  const [confirmingCode, setConfirmingCode] = useState<string | null>(null)
  const actionBtnRefs = useRef<Record<string, HTMLButtonElement | null>>({})
  const confirmBtnRef = useRef<HTMLButtonElement>(null)
  const lastConfirmingCodeRef = useRef<string | null>(null)

  // Same focus-follows-confirm pattern as PersonPage: into the Confirm
  // button when the row opens its confirm step, back to that row's Revoke
  // button once it closes either way.
  useEffect(() => {
    if (confirmingCode) {
      confirmBtnRef.current?.focus()
      lastConfirmingCodeRef.current = confirmingCode
    } else if (lastConfirmingCodeRef.current) {
      actionBtnRefs.current[lastConfirmingCodeRef.current]?.focus()
      lastConfirmingCodeRef.current = null
    }
  }, [confirmingCode])

  const submit = (e: FormEvent) => {
    e.preventDefault()
    mint.mutate(
      { recipientEmail: email.trim(), note: note.trim() },
      { onSuccess: code => setLink(inviteLink(code)) },
    )
  }

  const copy = async () => {
    if (!link) return
    try {
      await navigator.clipboard.writeText(link)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // Clipboard access can be denied (permissions, insecure context); the
      // link is still selectable in the field, so this is not fatal.
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.invites}</h1>
      <form onSubmit={submit} className="admin-panel flex flex-wrap items-end gap-2 p-2">
        <label className="flex flex-col">
          <span className="admin-label">{A.invites.emailLabel}</span>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)}
            className="border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]" />
        </label>
        <label className="flex flex-col">
          <span className="admin-label">{A.invites.noteLabel}</span>
          <input value={note} onChange={e => setNote(e.target.value)} maxLength={120}
            className="border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]" />
        </label>
        <button type="submit" disabled={mint.isPending} className="border border-[var(--a-info)] px-3 py-1 text-[var(--a-info)]">
          {A.invites.create}
        </button>
        {link ? (
          <>
            <input readOnly aria-label={A.invites.linkLabel} value={link} onFocus={e => e.currentTarget.select()}
              className="min-w-[320px] flex-1 border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1 text-[var(--a-strong)]" />
            <button type="button" onClick={() => void copy()} className="border border-[var(--a-line)] px-2 py-1">
              {copied ? A.invites.copied : A.invites.copy}
            </button>
          </>
        ) : null}
        {mint.error ? <p className="sev-fail">{mint.error.message}</p> : null}
      </form>
      {revoke.error ? <p className="sev-fail">{revoke.error.message}</p> : null}
      <table className="admin-panel w-full">
        <thead>
          <tr className="admin-label text-left">
            <th scope="col" className="p-1">{A.invites.colCode}</th><th scope="col">{A.invites.colStatus}</th><th scope="col">{A.invites.colFor}</th>
            <th scope="col">{A.invites.colBy}</th><th scope="col">{A.invites.colExpires}</th><th scope="col"><span className="sr-only">{A.invites.colActions}</span></th>
          </tr>
        </thead>
        <tbody>
          {(invites.data ?? []).map(i => (
            <tr key={i.code} className="border-t border-[var(--a-line)]">
              <td className="admin-strong p-1">{i.code}</td>
              <td className={tone[i.status]}>{i.status}</td>
              <td>{i.recipient_email ?? i.note ?? ''}</td>
              <td>{i.minted_by_handle ?? ''}</td>
              <td>{i.expires_at.slice(0, 10)}</td>
              <td>
                {i.status === 'active' ? (
                  confirmingCode === i.code ? (
                    <span role="group" aria-label={A.invites.confirmGroupLabel} className="inline-flex items-center gap-2">
                      <span className="text-[var(--a-muted)]">{A.invites.confirmPrompt(i.code)}</span>
                      <button
                        ref={confirmBtnRef}
                        type="button"
                        className="border border-[var(--a-line)] px-2"
                        onClick={() => {
                          revoke.mutate(i.code)
                          setConfirmingCode(null)
                        }}
                      >
                        {A.invites.confirm}
                      </button>
                      <button
                        type="button"
                        className="border border-[var(--a-line)] px-2"
                        onClick={() => setConfirmingCode(null)}
                      >
                        {A.invites.cancel}
                      </button>
                    </span>
                  ) : (
                    <button
                      ref={el => { actionBtnRefs.current[i.code] = el }}
                      type="button"
                      onClick={() => setConfirmingCode(i.code)}
                      className="border border-[var(--a-line)] px-2 text-[var(--a-fail)]"
                    >
                      {A.invites.revoke}
                    </button>
                  )
                ) : null}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
