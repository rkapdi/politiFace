import { useState, type FormEvent } from 'react'
import {
  joinLiveSessionGuest,
  liveReveal,
  liveScoreboard,
  signInAnonymously,
  submitLiveAnswer,
  type LiveJoin,
  type LiveRevealData,
  type ScoreboardRow,
} from '../lib/api'
import { useLiveSession } from '../lib/live'
import { Alert, Badge, Button, Card, Spinner } from '../components/ui'
import { Countdown } from '../components/Countdown'
import { Scoreboard } from '../components/Scoreboard'
import { useQuery } from '@tanstack/react-query'

function codeFromHash(): string {
  const m = window.location.hash.match(/[?&]code=([A-Za-z0-9]+)/)
  return m ? m[1].toUpperCase() : ''
}

function JoinForm({ onJoined }: { onJoined: (s: LiveJoin) => void }) {
  const [code, setCode] = useState(codeFromHash)
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signInAnonymously()
      const session = await joinLiveSessionGuest(
        code.trim().toUpperCase(),
        name.trim(),
      )
      onJoined(session)
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="mx-auto mt-16 max-w-sm px-4">
      <h1 className="mb-1 text-xl font-semibold text-slate-900">
        Join a live session
      </h1>
      <p className="mb-4 text-sm text-slate-500">
        No account needed. Your name appears on this session's scoreboard
        only, then it is deleted.
      </p>
      <Card>
        <form onSubmit={e => void submit(e)} className="flex flex-col gap-3">
          <label className="text-sm font-medium text-slate-700" htmlFor="join-code">
            Session code
          </label>
          <input
            id="join-code"
            required
            autoComplete="off"
            value={code}
            onChange={e => setCode(e.target.value.toUpperCase())}
            className="rounded-md border border-slate-300 px-3 py-2 text-center text-lg font-semibold tracking-[0.3em] uppercase focus-visible:outline-2 focus-visible:outline-slate-900"
          />
          <label className="text-sm font-medium text-slate-700" htmlFor="join-name">
            Your name
          </label>
          <input
            id="join-name"
            required
            minLength={2}
            maxLength={40}
            value={name}
            onChange={e => setName(e.target.value)}
            className="rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-slate-900"
          />
          <Button type="submit" disabled={busy}>
            Join
          </Button>
        </form>
        {error ? (
          <div className="mt-3">
            <Alert tone="error">{error}</Alert>
          </div>
        ) : null}
      </Card>
    </main>
  )
}

function GuestSession({ joined }: { joined: LiveJoin }) {
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
    <main className="mx-auto mt-8 max-w-md px-4">
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-lg font-semibold text-slate-900">{joined.title}</h1>
        <Badge tone={status === 'ended' ? 'slate' : 'green'}>{status}</Badge>
      </div>
      {error ? <Alert tone="error">{error}</Alert> : null}

      {status === 'lobby' ? (
        <Card className="py-10 text-center">
          <p className="text-base font-medium text-slate-900">You are in.</p>
          <p className="mt-1 text-sm text-slate-500">
            Waiting for your instructor to start.
          </p>
        </Card>
      ) : null}

      {status === 'question' && state?.question ? (
        <Card>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-sm text-slate-500">
              Question {(state.index ?? 0) + 1} of {state.total}
            </span>
            <Countdown
              startedAt={state.started_at}
              questionSeconds={state.question_seconds ?? joined.question_seconds}
            />
          </div>
          <p className="text-base font-medium text-slate-900">
            {state.question.stem}
          </p>
          <div className="mt-3 flex flex-col gap-2">
            {state.question.options.map(o => (
              <Button
                key={o.key}
                variant={myAnswer === o.key ? 'primary' : 'ghost'}
                disabled={myAnswer !== undefined}
                onClick={() => void answer(o.key)}
                className="justify-start text-left"
              >
                <span className="font-semibold">{o.key.toUpperCase()}</span>
                <span>{o.text}</span>
              </Button>
            ))}
          </div>
          {myAnswer !== undefined ? (
            <p role="status" className="mt-3 text-sm text-green-700">
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
    </main>
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
      <p className="text-sm text-slate-500">Correct answer</p>
      <p className="mt-1 text-lg font-semibold text-green-700">
        {r.correct_key.toUpperCase()}
      </p>
      {r.explanation ? (
        <p className="mt-2 text-sm text-slate-600">{r.explanation}</p>
      ) : null}
      <p className="mt-3 text-sm text-slate-500">
        Next question starts when your instructor advances.
      </p>
    </Card>
  )
}

function GuestEnded({ sessionId }: { sessionId: string }) {
  const board = useQuery<ScoreboardRow[]>({
    queryKey: ['guest', sessionId, 'final'],
    queryFn: () => liveScoreboard(sessionId),
  })
  const me = board.data?.find(r => r.is_me)
  return (
    <div className="flex flex-col gap-4">
      {me ? (
        <Card className="text-center">
          <p className="text-sm text-slate-500">Your result</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">
            #{me.rank} · {me.score} pts
          </p>
        </Card>
      ) : null}
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          Final standings
        </h2>
        {board.data ? <Scoreboard rows={board.data.slice(0, 10)} /> : <Spinner />}
      </Card>
      <Card className="text-center">
        <p className="text-sm text-slate-600">
          Keep practicing for the FCLE with the Politiface app, supplemental
          practice you choose.
        </p>
        <a
          href="https://politiface.app/"
          className="mt-2 inline-block text-sm font-medium text-slate-900 underline"
        >
          Get Politiface
        </a>
      </Card>
    </div>
  )
}

export function JoinPage() {
  const [joined, setJoined] = useState<LiveJoin | null>(null)
  return joined ? (
    <GuestSession joined={joined} />
  ) : (
    <JoinForm onJoined={setJoined} />
  )
}
