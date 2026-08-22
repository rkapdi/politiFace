import { useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import { Alert, Button, Card } from '../components/ui'

export function SignIn() {
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
      setError('We could not send a code to that address. Check the email and try again.')
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
    if (error) {
      setError('That code did not match. Codes expire quickly; request a new one if needed.')
    }
  }

  return (
    <main className="mx-auto mt-16 max-w-sm px-4">
      <h1 className="mb-1 text-xl font-semibold text-slate-900">
        Politiface faculty console
      </h1>
      <p className="mb-4 text-sm text-slate-500">
        Sign in with your email. We send you a 6-digit code; there is no
        password.
      </p>
      <Card>
        {step === 'email' ? (
          <form onSubmit={sendCode} className="flex flex-col gap-3">
            <label className="text-sm font-medium text-slate-700" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              className="rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900"
            />
            <Button type="submit" disabled={busy}>
              Send code
            </Button>
          </form>
        ) : (
          <form onSubmit={verify} className="flex flex-col gap-3">
            <p className="text-sm text-slate-600">
              We emailed a 6-digit code to <b>{email.trim()}</b>.
            </p>
            <label className="text-sm font-medium text-slate-700" htmlFor="code">
              Code
            </label>
            <input
              id="code"
              inputMode="numeric"
              pattern="[0-9]{6}"
              required
              autoComplete="one-time-code"
              value={code}
              onChange={e => setCode(e.target.value)}
              className="rounded-md border border-slate-300 px-3 py-2 text-sm tracking-widest focus-visible:outline-2 focus-visible:outline-slate-900"
            />
            <Button type="submit" disabled={busy}>
              Sign in
            </Button>
            <Button type="button" variant="ghost" onClick={() => setStep('email')}>
              Use a different email
            </Button>
          </form>
        )}
        {error ? (
          <div className="mt-3">
            <Alert tone="error">{error}</Alert>
          </div>
        ) : null}
      </Card>
    </main>
  )
}
