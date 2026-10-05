import { useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import { logOpsEvent } from '../lib/opsLog'
import { S } from '../lib/strings'
import { Alert, Button } from '../components/ui'

const field =
  'rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900'

// Supabase auth errors carry a numeric status and, on rate limits, a code
// like "over_email_send_rate_limit" or "over_request_rate_limit". Those are
// not the same failure as a bad email or a bad code, and showing that copy
// during a real campus-day traffic spike sends everyone off retyping their
// email for no reason.
function isRateLimited(error: { status?: number; code?: string }): boolean {
  return error.status === 429 || (error.code ?? '').startsWith('over_')
}

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
    try {
      const { error } = await supabase.auth.signInWithOtp({ email: email.trim() })
      if (error) {
        logOpsEvent('signin_send_failed', {
          code: String(error.code ?? error.status ?? 'unknown'),
          detail: { status: error.status ?? null },
          email: email.trim(),
        })
        setError(isRateLimited(error) ? S.signIn.rateLimited : S.signIn.sendFailed)
        return
      }
      setStep('code')
    } catch {
      logOpsEvent('signin_send_failed', { code: 'thrown', email: email.trim() })
      setError(S.signIn.sendFailed)
    } finally {
      setBusy(false)
    }
  }

  const verify = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { error } = await supabase.auth.verifyOtp({
        email: email.trim(),
        token: code.trim(),
        type: 'email',
      })
      if (error) {
        logOpsEvent('signin_verify_failed', {
          code: String(error.code ?? error.status ?? 'unknown'),
          detail: { status: error.status ?? null },
          email: email.trim(),
        })
        setError(isRateLimited(error) ? S.signIn.rateLimited : S.signIn.badCode)
      }
    } catch {
      logOpsEvent('signin_verify_failed', { code: 'thrown', email: email.trim() })
      setError(S.signIn.badCode)
    } finally {
      setBusy(false)
    }
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
