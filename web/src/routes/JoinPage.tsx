import { useState, type FormEvent } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  joinLiveSession,
  joinLiveSessionAsStudent,
  joinLiveSessionGuest,
  liveReveal,
  liveScoreboard,
  liveSessionPreview,
  signInAnonymously,
  submitLiveAnswer,
  type LiveJoin,
  type LiveRevealData,
  type ScoreboardRow,
  type SessionPreview,
} from '../lib/api'
import { useSession } from '../auth/SessionProvider'
import { EmailCodeForm } from '../auth/EmailCodeForm'
import { useLiveSession } from '../lib/live'
import { logOpsEvent } from '../lib/opsLog'
import { PublicPage } from '../components/Brand'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card, Spinner } from '../components/ui'
import { Countdown } from '../components/Countdown'
import { Scoreboard } from '../components/Scoreboard'

const field =
  'rounded-md border border-field-line bg-field text-ink px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-focus'

function CodeEntry({ onCode }: { onCode: (c: string) => void }) {
  const [code, setCode] = useState('')
  return (
    <Card>
      <form
        onSubmit={e => {
          e.preventDefault()
          onCode(code.trim().toUpperCase())
        }}
        className="flex flex-col gap-3"
      >
        <label className="text-sm font-medium text-ink-2" htmlFor="join-code">
          {S.student.sessionCode}
        </label>
        <input id="join-code" required autoComplete="off" value={code}
          onChange={e => setCode(e.target.value.toUpperCase())}
          className={`${field} text-center text-lg font-semibold tracking-[0.3em] uppercase`} />
        <Button type="submit">{S.join.continue}</Button>
      </form>
    </Card>
  )
}

function GuestJoin({ code, onJoined }: { code: string; onJoined: (s: LiveJoin) => void }) {
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signInAnonymously()
      onJoined(await joinLiveSessionGuest(code, name.trim()))
    } catch (err) {
      logOpsEvent('join_refused', {
        code: (err as Error).message.slice(0, 80),
        detail: { session_code: code },
      })
      setError((err as Error).message)
    } finally {
      setBusy(false)
    }
  }
  return (
    <Card>
      <p className="mb-3 text-sm text-ink-3">{S.join.guestNote}</p>
      <form onSubmit={e => void submit(e)} className="flex flex-col gap-3">
        <label className="text-sm font-medium text-ink-2" htmlFor="guest-name">
          {S.join.guestName}
        </label>
        <input id="guest-name" required minLength={2} maxLength={40} value={name}
          onChange={e => setName(e.target.value)} className={field} />
        <Button type="submit" disabled={busy}>Join</Button>
      </form>
      {error ? <div className="mt-3"><Alert tone="error">{error}</Alert></div> : null}
    </Card>
  )
}

function StudentJoin({
  code, preview, onJoined,
}: { code: string; preview: SessionPreview; onJoined: (s: LiveJoin) => void }) {
  const { session, signOut } = useSession()
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const run = async (fn: () => Promise<LiveJoin>) => {
    setBusy(true)
    setError(null)
    try {
      onJoined(await fn())
    } catch (err) {
      logOpsEvent('join_refused', {
        code: (err as Error).message.slice(0, 80),
        detail: { session_code: code },
      })
      setError((err as Error).message)
    } finally {
      setBusy(false)
    }
  }

  const teaching = preview.role === 'faculty' || preview.role === 'ta'

  return (
    <Card>
      {teaching ? (
        <p className="text-sm text-ink-2">
          {S.errors.youTeach}{' '}
          <a href="#/" className="font-medium underline">{S.join.openConsole}</a>
        </p>
      ) : preview.is_member ? (
        <Button disabled={busy} className="w-full justify-center"
          onClick={() => void run(() => joinLiveSession(code))}>
          {S.join.joinAs} {preview.roster_name ?? S.join.yourself}
        </Button>
      ) : (
        <form
          onSubmit={e => {
            e.preventDefault()
            void run(() => joinLiveSessionAsStudent(code, name.trim()))
          }}
          className="flex flex-col gap-3"
        >
          <label className="text-sm font-medium text-ink-2" htmlFor="roster-name">
            {S.join.firstTimeName}
          </label>
          <input id="roster-name" required minLength={2} maxLength={60} value={name}
            autoComplete="name" onChange={e => setName(e.target.value)} className={field} />
          <Button type="submit" disabled={busy}>
            {S.join.joinClass} {preview.class_name}
          </Button>
        </form>
      )}
      {error ? <div className="mt-3"><Alert tone="error">{error}</Alert></div> : null}
      <div className="mt-3 text-center">
        {/* Shared lab computers: make it obvious which account is signed in
            before someone taps a wrong-account "Join". */}
        {session?.user.email ? (
          <p className="mb-1 text-xs text-ink-3">
            {S.join.signedInAs} {session.user.email}.
          </p>
        ) : null}
        <Button variant="ghost" onClick={() => void signOut()}>{S.join.notYou}</Button>
      </div>
    </Card>
  )
}

function SessionView({ joined }: { joined: LiveJoin }) {
  const { state, error } = useLiveSession(joined.id)
  const [answers, setAnswers] = useState<Record<string, string>>({})
  const [submitError, setSubmitError] = useState<string | null>(null)

  const status = state?.status ?? joined.status
  const questionId = state?.question?.id
  const myAnswer = questionId ? answers[questionId] : undefined

  const answer = async (key: string) => {
    if (!questionId || myAnswer) return
    setAnswers(prev => ({ ...prev, [questionId]: key }))
    setSubmitError(null)
    try {
      await submitLiveAnswer(joined.id, questionId, key)
    } catch (err) {
      setSubmitError((err as Error).message)
    }
  }

  return (
    <PublicPage>
      <div className="mb-4 flex items-center justify-between">
        <h1 className="px-2 text-[28px] font-bold leading-tight tracking-[-0.03em] text-ink">{joined.title}</h1>
        <Badge tone={status === 'ended' ? 'slate' : 'green'}>{status}</Badge>
      </div>
      {error ? <Alert tone="error">{error}</Alert> : null}

      {status === 'lobby' ? (
        <Card className="py-10 text-center">
          <p className="text-base font-medium text-ink">You are in.</p>
          <p className="mt-1 text-sm text-ink-3">
            Waiting for your instructor to start.
          </p>
        </Card>
      ) : null}

      {status === 'question' && state?.question ? (
        <Card>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-sm text-ink-3">
              Question {(state.index ?? 0) + 1} of {state.total}
            </span>
            <Countdown
              startedAt={state.started_at}
              questionSeconds={state.question_seconds ?? joined.question_seconds}
            />
          </div>
          <p className="text-base font-medium text-ink">
            {state.question.stem}
          </p>
          <div className="mt-3 flex flex-col gap-2">
            {state.question.options.map(o => (
              <button
                key={o.key}
                type="button"
                aria-pressed={myAnswer === o.key}
                disabled={myAnswer !== undefined}
                onClick={() => void answer(o.key)}
                className="flex min-h-[60px] w-full items-center gap-3.5 rounded-lg border-2 border-transparent bg-raised px-4 py-3 text-left text-base font-semibold text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus enabled:hover:border-line-strong disabled:cursor-default aria-pressed:border-ink disabled:aria-[pressed=false]:opacity-55"
              >
                <span className="flex size-8 shrink-0 items-center justify-center rounded-md bg-control text-sm font-extrabold">
                  {o.key.toUpperCase()}
                </span>
                <span className="min-w-0 flex-1">{o.text}</span>
              </button>
            ))}
          </div>
          {myAnswer !== undefined ? (
            <p role="status" className="mt-3 text-sm font-semibold text-ink">
              Answer is in. Results at the reveal.
            </p>
          ) : null}
          {submitError ? (
            <div className="mt-3">
              <Alert tone="error">{submitError}</Alert>
            </div>
          ) : null}
        </Card>
      ) : null}

      {status === 'reveal' ? (
        <GuestReveal sessionId={joined.id} index={state?.index ?? 0} />
      ) : null}

      {status === 'ended' ? <GuestEnded sessionId={joined.id} /> : null}
    </PublicPage>
  )
}

function GuestReveal({ sessionId, index }: { sessionId: string; index: number }) {
  const reveal = useQuery<LiveRevealData>({
    queryKey: ['guest', sessionId, 'reveal', index],
    queryFn: () => liveReveal(sessionId),
  })
  if (reveal.isPending) return <Spinner label="Loading the answer" />
  if (reveal.error) return <Alert tone="error">{reveal.error.message}</Alert>
  const r = reveal.data
  if (!r) return null
  return (
    <Card>
      <p className="text-sm text-ink-3">Correct answer</p>
      <p className="mt-1 text-lg font-semibold text-pass">
        {r.correct_key.toUpperCase()}
      </p>
      {r.explanation ? (
        <p className="mt-2 text-sm text-ink-2">{r.explanation}</p>
      ) : null}
      <p className="mt-3 text-sm text-ink-3">
        Next question starts when your instructor advances.
      </p>
    </Card>
  )
}

function GuestEnded({ sessionId }: { sessionId: string }) {
  const { session } = useSession()
  const board = useQuery<ScoreboardRow[]>({
    queryKey: ['guest', sessionId, 'final'],
    queryFn: () => liveScoreboard(sessionId),
  })
  const me = board.data?.find(r => r.is_me)
  const hasHome = session !== null && !session.user.is_anonymous
  return (
    <div className="flex flex-col gap-4">
      {me ? (
        <Card className="text-center">
          <p className="text-sm text-ink-3">Your result</p>
          <p className="mt-1 text-2xl font-bold text-ink">
            #{me.rank} · {me.score} pts
          </p>
        </Card>
      ) : null}
      <Card>
        <h2 className="mb-3 text-base font-bold text-ink">
          Final standings
        </h2>
        {board.data ? <Scoreboard rows={board.data.slice(0, 10)} /> : <Spinner />}
      </Card>
      <Card className="text-center">
        <p className="text-sm text-ink-2">
          Keep practicing for the FCLE with the Politiface app, supplemental
          practice you choose.
        </p>
        <a
          href="https://politiface.app/"
          className="mt-2 inline-block text-sm font-medium text-ink underline"
        >
          Get Politiface
        </a>
        {hasHome ? (
          <a
            href="#/"
            className="mt-2 block text-sm font-medium text-ink underline"
          >
            {S.join.backHome}
          </a>
        ) : null}
      </Card>
    </div>
  )
}

function codeFromHash(): string {
  const m = window.location.hash.match(/[?&]code=([A-Za-z0-9]+)/)
  return m ? m[1].toUpperCase() : ''
}

export function JoinPage() {
  const { session, loading } = useSession()
  const [code, setCodeState] = useState(codeFromHash)
  // Keep a typed code in the URL, so a reload mid-session (flaky campus wifi)
  // lands back on this session instead of an empty form.
  const setCode = (next: string) => {
    window.history.replaceState(null, '', `#/join?code=${encodeURIComponent(next)}`)
    setCodeState(next)
  }
  const [joined, setJoined] = useState<LiveJoin | null>(null)
  const [asGuest, setAsGuest] = useState(false)
  // While the session is still resolving, session is always null: do not
  // let that masquerade as signed-out (it would run and cache the preview
  // query under the signed-out key, which a returning signed-in student
  // then briefly sees).
  const signedIn = !loading && session !== null && !session.user.is_anonymous
  const preview = useQuery({
    queryKey: ['live-preview', code, signedIn ? session.user.id : 'signed-out'],
    queryFn: () => liveSessionPreview(code),
    enabled: code !== '' && !loading,
    retry: 1,
  })

  if (joined) return <SessionView joined={joined} />

  if (loading) {
    return (
      <PublicPage>
        <h1 className="px-1.5 text-[28px] font-bold leading-tight tracking-[-0.03em] text-ink">{S.join.title}</h1>
        <Spinner label={S.common.checkingSession} />
      </PublicPage>
    )
  }

  const badCode = preview.error?.message === S.errors.badSessionCode

  return (
    <PublicPage>
      <h1 className="px-1.5 text-[28px] font-bold leading-tight tracking-[-0.03em] text-ink">{S.join.title}</h1>
      {code === '' ? (
        <CodeEntry onCode={setCode} />
      ) : preview.isPending ? (
        <Spinner />
      ) : preview.error ? (
        <>
          <Alert tone="error">{preview.error.message}</Alert>
          {badCode ? (
            <CodeEntry onCode={setCode} />
          ) : (
            <Button onClick={() => void preview.refetch()}>{S.join.tryAgain}</Button>
          )}
        </>
      ) : (
        <>
          <Card>
            <p className="text-base font-semibold text-ink">{preview.data.title}</p>
            <p className="text-sm text-ink-2">
              {preview.data.class_name}
              {preview.data.professor ? ` ${S.join.with} ${preview.data.professor}` : ''}
            </p>
          </Card>
          {signedIn ? (
            <StudentJoin code={code} preview={preview.data} onJoined={setJoined} />
          ) : asGuest ? (
            <GuestJoin code={code} onJoined={setJoined} />
          ) : (
            <>
              <Card>
                <EmailCodeForm hint={S.join.signInIntro} />
              </Card>
              {preview.data.allow_guests ? (
                <Button variant="ghost" onClick={() => setAsGuest(true)}>
                  {S.join.guest}
                </Button>
              ) : null}
            </>
          )}
        </>
      )}
    </PublicPage>
  )
}
