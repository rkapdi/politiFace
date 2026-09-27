import { useState, type FormEvent } from 'react'
import * as Dialog from '@radix-ui/react-dialog'
import { useSession } from '../auth/SessionProvider'
import { supabase } from '../lib/supabase'
import {
  useCohortCoFaculty,
  useDeleteAccount,
  useDeletionBlockers,
  useMyProfile,
  useTransferOwnership,
  useUpdateMyProfile,
  type DeletionBlocker,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card } from '../components/ui'
import { SkeletonTable } from '../components/Skeleton'

function ProfileSection({ userId }: { userId: string }) {
  const profile = useMyProfile(userId)
  const update = useUpdateMyProfile()
  const [saved, setSaved] = useState(false)

  if (profile.isPending) return <SkeletonTable rows={2} />
  if (profile.error) return <Alert tone="error">{profile.error.message}</Alert>

  const submit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const data = new FormData(e.currentTarget)
    setSaved(false)
    update.mutate(
      {
        handle: String(data.get('handle') ?? '').trim(),
        school: String(data.get('school') ?? '').trim(),
      },
      { onSuccess: () => setSaved(true) },
    )
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-3">
      <div>
        <label
          htmlFor="account-handle"
          className="block text-sm font-medium text-slate-700"
        >
          {S.account.displayName}
        </label>
        <p className="text-xs text-slate-500">{S.account.displayNameHint}</p>
        <input
          id="account-handle"
          name="handle"
          required
          minLength={3}
          maxLength={20}
          defaultValue={profile.data.handle}
          className="mt-1 w-full max-w-xs rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
      </div>
      <div>
        <label
          htmlFor="account-school"
          className="block text-sm font-medium text-slate-700"
        >
          {S.account.school}
        </label>
        <input
          id="account-school"
          name="school"
          maxLength={120}
          defaultValue={profile.data.school ?? ''}
          className="mt-1 w-full max-w-xs rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" disabled={update.isPending}>
          {S.common.save}
        </Button>
        {saved ? (
          <span role="status" className="text-sm text-slate-600">
            {S.account.saved}
          </span>
        ) : null}
      </div>
      {update.error ? <Alert tone="error">{update.error.message}</Alert> : null}
    </form>
  )
}

function EmailSection({ email }: { email: string }) {
  const [editing, setEditing] = useState(false)
  const [pending, setPending] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const submit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const next = String(new FormData(e.currentTarget).get('email') ?? '').trim()
    setBusy(true)
    setError(null)
    const { error } = await supabase.auth.updateUser({ email: next })
    setBusy(false)
    if (error) {
      setError(S.errors.generic)
      return
    }
    setEditing(false)
    setPending(true)
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-slate-700">
        Signed in as <b>{email}</b>
      </p>
      {pending ? <Alert tone="info">{S.account.emailPending}</Alert> : null}
      {editing ? (
        <form onSubmit={submit} className="flex flex-wrap items-end gap-3">
          <label className="text-sm text-slate-700">
            {S.account.newEmail}
            <input
              name="email"
              type="email"
              required
              autoComplete="email"
              className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
            />
          </label>
          <Button type="submit" disabled={busy}>
            {S.account.changeEmail}
          </Button>
          <Button type="button" variant="ghost" onClick={() => setEditing(false)}>
            {S.common.cancel}
          </Button>
        </form>
      ) : (
        <div>
          <Button variant="ghost" onClick={() => setEditing(true)}>
            {S.account.changeEmail}
          </Button>
        </div>
      )}
      {error ? <Alert tone="error">{error}</Alert> : null}
    </div>
  )
}

function SessionsSection() {
  const [busy, setBusy] = useState(false)
  const signOutEverywhere = async () => {
    setBusy(true)
    // Revokes every refresh token, this device's included; RequireAuth then
    // routes to the sign-in screen.
    await supabase.auth.signOut({ scope: 'global' })
  }
  return (
    <div>
      <Button variant="ghost" onClick={() => void signOutEverywhere()} disabled={busy}>
        {S.account.signOutEverywhere}
      </Button>
      <p className="mt-2 text-xs text-slate-500">
        {S.account.signOutEverywhereHint}
      </p>
    </div>
  )
}

function BlockedClassRow({
  blocker,
  userId,
}: {
  blocker: DeletionBlocker
  userId: string
}) {
  const coFaculty = useCohortCoFaculty(blocker.cohort_id, userId)
  const transfer = useTransferOwnership()
  const [target, setTarget] = useState('')

  return (
    <li className="flex flex-wrap items-center gap-3 border-b border-slate-100 py-2">
      <span className="text-sm font-medium text-slate-900">{blocker.name}</span>
      {coFaculty.data && coFaculty.data.length > 0 ? (
        <>
          <label className="text-sm text-slate-700">
            {S.account.transferTo}
            <select
              value={target}
              onChange={e => setTarget(e.target.value)}
              className="ml-2 rounded-md border border-slate-300 px-2 py-1 text-sm"
            >
              <option value="">Choose</option>
              {coFaculty.data.map(f => (
                <option key={f.user_id} value={f.user_id}>
                  {f.display}
                </option>
              ))}
            </select>
          </label>
          <Button
            variant="ghost"
            disabled={target === '' || transfer.isPending}
            onClick={() =>
              transfer.mutate({ cohortId: blocker.cohort_id, newOwner: target })
            }
          >
            {S.account.transferOwnership}
          </Button>
        </>
      ) : (
        <span className="text-sm text-slate-500">{S.account.noCoFaculty}</span>
      )}
      {transfer.error ? (
        <Alert tone="error">{transfer.error.message}</Alert>
      ) : null}
    </li>
  )
}

function DangerSection({ userId }: { userId: string }) {
  const blockers = useDeletionBlockers()
  const del = useDeleteAccount()
  const [open, setOpen] = useState(false)
  const [confirm, setConfirm] = useState('')

  if (blockers.isPending) return <SkeletonTable rows={1} />
  if (blockers.error) {
    return <Alert tone="error">{blockers.error.message}</Alert>
  }

  const blocked = blockers.data ?? []
  if (blocked.length > 0) {
    return (
      <div className="flex flex-col gap-2">
        <Alert tone="info">{S.account.blockedIntro}</Alert>
        <ul className="flex flex-col">
          {blocked.map(b => (
            <BlockedClassRow key={b.cohort_id} blocker={b} userId={userId} />
          ))}
        </ul>
      </div>
    )
  }

  const erase = () => {
    del.mutate(undefined, {
      onSuccess: () => {
        // The auth user is gone server-side; drop the local session too.
        void supabase.auth.signOut().catch(() => undefined)
      },
    })
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-slate-600">{S.account.deleteWarning}</p>
      <div>
        <Button variant="danger" onClick={() => setOpen(true)}>
          {S.account.deleteAccount}
        </Button>
      </div>
      <Dialog.Root
        open={open}
        onOpenChange={o => {
          setOpen(o)
          if (!o) setConfirm('')
        }}
      >
        <Dialog.Portal>
          <Dialog.Overlay className="fixed inset-0 bg-slate-900/40" />
          <Dialog.Content className="fixed left-1/2 top-1/2 w-[min(28rem,90vw)] -translate-x-1/2 -translate-y-1/2 rounded-lg bg-white p-4 shadow-lg">
            <Dialog.Title className="text-base font-semibold text-slate-900">
              {S.account.deleteAccount}
            </Dialog.Title>
            <Dialog.Description className="mt-1 text-sm text-slate-500">
              {S.account.deleteWarning}
            </Dialog.Description>
            <label
              htmlFor="delete-confirm"
              className="mt-3 block text-sm font-medium text-slate-700"
            >
              {S.account.deleteConfirmPrompt}
            </label>
            <input
              id="delete-confirm"
              value={confirm}
              onChange={e => setConfirm(e.target.value)}
              className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
            />
            {del.error ? (
              <div className="mt-2">
                <Alert tone="error">{del.error.message}</Alert>
              </div>
            ) : null}
            <div className="mt-4 flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setOpen(false)}>
                {S.common.cancel}
              </Button>
              <Button
                variant="danger"
                disabled={confirm !== 'DELETE' || del.isPending}
                onClick={erase}
              >
                {S.account.deleteAccount}
              </Button>
            </div>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </div>
  )
}

export function AccountPage() {
  const { session } = useSession()
  const userId = session?.user.id ?? ''
  const email = session?.user.email ?? ''

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-4">
      <h1 className="text-lg font-semibold text-slate-900">
        {S.account.title}
      </h1>
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          {S.account.profileHeading}
        </h2>
        <ProfileSection userId={userId} />
      </Card>
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          {S.account.emailHeading}
        </h2>
        <EmailSection email={email} />
      </Card>
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          {S.account.sessionsHeading}
        </h2>
        <SessionsSection />
      </Card>
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-red-700">
          {S.account.dangerHeading}
        </h2>
        <DangerSection userId={userId} />
      </Card>
    </div>
  )
}
