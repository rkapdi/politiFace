import { useEffect, useState, type FormEvent } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useSession } from '../auth/SessionProvider'
import { EmailCodeForm } from '../auth/EmailCodeForm'
import {
  invitePreview,
  myConsoleRole,
  redeemFacultyInvite,
  useCreateCohort,
  useMyProfile,
  useUpdateMyProfile,
} from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card, Spinner } from '../components/ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

function inviteFromHash(): string {
  const m = window.location.hash.match(/[?&]invite=([A-Za-z0-9]+)/)
  return m ? m[1].toUpperCase() : ''
}

// Generated handles ("user_1a2b...") are placeholders, not names.
const isGenerated = (h: string | undefined) => !h || /^user_[0-9a-f]{8,12}$/.test(h)

function Setup({ userId }: { userId: string }) {
  const profile = useMyProfile(userId)
  const update = useUpdateMyProfile()
  const create = useCreateCohort()
  const [step, setStep] = useState<'profile' | 'class'>('profile')
  const [handle, setHandle] = useState('')
  const [school, setSchool] = useState('')
  const [name, setName] = useState('')
  const [term, setTerm] = useState('')
  const [seeded, setSeeded] = useState(false)

  useEffect(() => {
    if (seeded || !profile.data) return
    setSeeded(true)
    if (!isGenerated(profile.data.handle)) setHandle(profile.data.handle)
    setSchool(profile.data.school ?? '')
  }, [seeded, profile.data])

  const saveProfile = (e: FormEvent) => {
    e.preventDefault()
    update.mutate(
      { handle: handle.trim(), school: school.trim() },
      { onSuccess: () => setStep('class') },
    )
  }
  const createClass = (e: FormEvent) => {
    e.preventDefault()
    create.mutate(
      { name: name.trim(), term: term.trim() || null },
      {
        onSuccess: d => {
          window.location.hash = `#/class/${(d as { id: string }).id}`
        },
      },
    )
  }

  return step === 'profile' ? (
    <Card>
      <h2 className="text-base font-semibold text-slate-900">{S.welcome.stepProfile}</h2>
      <p className="mt-1 text-sm text-slate-500">{S.welcome.profileHint}</p>
      <form onSubmit={saveProfile} className="mt-3 flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.account.displayName}
          <input required minLength={3} maxLength={30} value={handle}
            onChange={e => setHandle(e.target.value)} className={field} />
        </label>
        <label className="text-sm text-slate-700">
          {S.account.school}
          <input maxLength={120} value={school}
            onChange={e => setSchool(e.target.value)} className={field} />
        </label>
        {update.error ? <Alert tone="error">{update.error.message}</Alert> : null}
        <div><Button type="submit" disabled={update.isPending}>{S.welcome.next}</Button></div>
      </form>
    </Card>
  ) : (
    <Card>
      <h2 className="text-base font-semibold text-slate-900">{S.welcome.stepClass}</h2>
      <p className="mt-1 text-sm text-slate-500">{S.welcome.classHint}</p>
      <form onSubmit={createClass} className="mt-3 flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.welcome.className}
          <input required minLength={3} value={name} placeholder={S.welcome.classNamePlaceholder}
            onChange={e => setName(e.target.value)} className={field} />
        </label>
        <label className="text-sm text-slate-700">
          {S.welcome.term}
          <input value={term} placeholder="2026F"
            onChange={e => setTerm(e.target.value)} className={field} />
        </label>
        {create.error ? <Alert tone="error">{create.error.message}</Alert> : null}
        <div><Button type="submit" disabled={create.isPending}>{S.welcome.createClass}</Button></div>
      </form>
    </Card>
  )
}

function Verify({ code, userId }: { code: string; userId: string }) {
  // Instructors who already have access skip the redeem (it would burn the code).
  const verified = useQuery({
    queryKey: ['welcome', 'verify', code, userId],
    queryFn: async () => {
      const role = await myConsoleRole()
      if (role !== 'staff' && role !== 'faculty') await redeemFacultyInvite(code)
      return true
    },
    retry: false,
    staleTime: Infinity,
  })
  if (verified.isPending) return <Spinner label={S.welcome.verifying} />
  if (verified.error) return <Alert tone="error">{verified.error.message}</Alert>
  return <Setup userId={userId} />
}

export function WelcomePage() {
  const { session, loading } = useSession()
  const [code] = useState(inviteFromHash)
  const preview = useQuery({
    queryKey: ['invite-preview', code],
    queryFn: () => invitePreview(code),
    enabled: code !== '' && !loading,
    retry: false,
  })
  // While the session is still resolving, session is always null: do not
  // let that masquerade as signed-out (a returning signed-in instructor
  // would otherwise briefly see the email-code form).
  const signedIn = !loading && session !== null && !session.user.is_anonymous

  useEffect(() => {
    document.title = 'Politiface: instructor invite'
  }, [])

  if (loading) {
    return (
      <main className="mx-auto mt-12 flex max-w-md flex-col gap-4 px-4">
        <h1 className="text-xl font-semibold text-slate-900">{S.welcome.title}</h1>
        <Spinner label={S.common.checkingSession} />
      </main>
    )
  }

  // Signed in, the redeem itself is the check: a professor who already
  // redeemed this code (so it previews as used) is verified and skips it.
  return (
    <main className="mx-auto mt-12 flex max-w-md flex-col gap-4 px-4">
      <h1 className="text-xl font-semibold text-slate-900">{S.welcome.title}</h1>
      {code === '' ? (
        <Alert tone="error">{S.welcome.invalid}</Alert>
      ) : signedIn ? (
        <Verify code={code} userId={session.user.id} />
      ) : preview.isPending ? (
        <Spinner />
      ) : preview.error ? (
        <Alert tone="error">{preview.error.message}</Alert>
      ) : !preview.data.valid ? (
        <Alert tone="error">{S.welcome.invalid}</Alert>
      ) : (
        <>
          {preview.data?.inviter ? (
            <p className="text-sm text-slate-600">
              {S.welcome.invitedBy} <b>{preview.data.inviter}</b>
            </p>
          ) : null}
          <Card>
            <EmailCodeForm />
          </Card>
        </>
      )}
    </main>
  )
}
