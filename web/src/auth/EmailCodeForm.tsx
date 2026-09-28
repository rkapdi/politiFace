import { useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import { S } from '../lib/strings'
import { Alert, Button } from '../components/ui'

const field =
  'rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900'

/** Email, then the emailed 6-digit code. The same account as the iOS app. */
export function EmailCodeForm({ hint }: { hint?: string }) {
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [step, setStep] = useState<'email' | 'code'>('email')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const sendCode = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    const { error } = await supabase.auth.signInWithOtp({ email: email.trim() })
    setBusy(false)
    if (error) {
      setError(S.signIn.sendFailed)
      return
    }
    setStep('code')
  }

  const verify = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: code.trim(),
      type: 'email',
    })
    setBusy(false)
    if (error) setError(S.signIn.badCode)
  }

  return (
    <div>
      {step === 'email' ? (
        <form onSubmit={sendCode} className="flex flex-col gap-3">
          {hint ? <p className="text-sm text-slate-600">{hint}</p> : null}
          <label className="text-sm font-medium text-slate-700" htmlFor="email">
            {S.signIn.email}
          </label>
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            className={field}
          />
          <Button type="submit" disabled={busy}>
            {S.signIn.sendCode}
          </Button>
        </form>
      ) : (
        <form onSubmit={verify} className="flex flex-col gap-3">
          <p className="text-sm text-slate-600">
            {S.signIn.sentTo} <b>{email.trim()}</b>.
          </p>
          <label className="text-sm font-medium text-slate-700" htmlFor="code">
            {S.signIn.code}
          </label>
          <input
            id="code"
            inputMode="numeric"
            pattern="[0-9]{6}"
            required
            autoComplete="one-time-code"
            value={code}
            onChange={e => setCode(e.target.value)}
            className={`${field} tracking-widest`}
          />
          <Button type="submit" disabled={busy}>
            {S.signIn.submit}
          </Button>
          <Button type="button" variant="ghost" onClick={() => setStep('email')}>
            {S.signIn.differentEmail}
          </Button>
        </form>
      )}
      {error ? (
        <div className="mt-3">
          <Alert tone="error">{error}</Alert>
        </div>
      ) : null}
    </div>
  )
}
