import { useEffect, useState } from 'react'
import { useParams } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import QRCode from 'qrcode'
import {
  liveReveal,
  liveScoreboard,
  useAdvanceLiveSession,
  useEndLiveSession,
  useLiveSessionMeta,
  useLogExport,
  useParticipantCount,
  useSessionReport,
  useSessionStats,
} from '../lib/api'
import { useLiveSession } from '../lib/live'
import { Alert, Badge, Button, Card, Spinner } from '../components/ui'
import { Countdown } from '../components/Countdown'
import { Scoreboard } from '../components/Scoreboard'
import { downloadCsv } from '../lib/csv'

export function LiveRunnerPage() {
  const { cohortId, sessionId } = useParams({ strict: false }) as {
    cohortId: string
    sessionId: string
  }
  return <LiveRunner cohortId={cohortId} sessionId={sessionId} />
}

function joinUrl(code: string): string {
  const base = `${window.location.origin}${window.location.pathname}`
  return `${base}#/join?code=${code}`
}

function Lobby({
  sessionId,
  code,
  onStart,
  starting,
}: {
  sessionId: string
  code: string
  onStart: () => void
  starting: boolean
}) {
  const participants = useParticipantCount(sessionId, true)
  const [qr, setQr] = useState<string | null>(null)

  useEffect(() => {
    void QRCode.toDataURL(joinUrl(code), { width: 220, margin: 1 }).then(setQr)
  }, [code])

  return (
    <Card className="flex flex-col items-center gap-4 py-8 text-center">
      <p className="text-sm text-slate-500">
        Students open the join page in any browser and enter this code, or
        scan the QR code. No app, no account.
      </p>
      <div className="text-5xl font-bold tracking-[0.3em] text-slate-900">
        {code}
      </div>
      {qr ? (
        <img src={qr} alt={`QR code that opens the join page with code ${code}`} />
      ) : null}
      <p aria-live="polite" className="text-sm text-slate-600">
        {participants.data ?? 0} joined
      </p>
      <Button onClick={onStart} disabled={starting}>
        Start first question
      </Button>
    </Card>
  )
}

function RevealPanel({ sessionId, index }: { sessionId: string; index: number }) {
  const reveal = useQuery({
    queryKey: ['session', sessionId, 'reveal', index],
    queryFn: () => liveReveal(sessionId),
  })
  const board = useQuery({
    queryKey: ['session', sessionId, 'board', index],
    queryFn: () => liveScoreboard(sessionId),
  })

  if (reveal.isPending) return <Spinner label="Loading results" />
  if (reveal.error) return <Alert tone="error">{reveal.error.message}</Alert>
  const r = reveal.data
  if (!r) return null

  const total = Object.values(r.counts).reduce((a, b) => a + b, 0)

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">Answers</h2>
        <ul className="flex flex-col gap-2">
          {Object.entries(r.counts)
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([key, n]) => (
              <li key={key} className="flex items-center gap-2 text-sm">
                <Badge tone={key === r.correct_key ? 'green' : 'slate'}>
                  {key.toUpperCase()}
                </Badge>
                <div className="h-3 flex-1 rounded-full bg-slate-100">
                  <div
                    className={`h-3 rounded-full ${key === r.correct_key ? 'bg-green-600' : 'bg-slate-400'}`}
                    style={{ width: total === 0 ? 0 : `${(n / total) * 100}%` }}
                  />
                </div>
                <span className="w-6 text-right tabular-nums">{n}</span>
              </li>
            ))}
        </ul>
        {r.explanation ? (
          <p className="mt-3 text-sm text-slate-600">{r.explanation}</p>
        ) : null}
      </Card>
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">Standings</h2>
        {board.data ? <Scoreboard rows={board.data} /> : <Spinner />}
      </Card>
    </div>
  )
}

function EndedPanel({
  cohortId,
  sessionId,
}: {
  cohortId: string
  sessionId: string
}) {
  const stats = useSessionStats(sessionId)
  const report = useSessionReport(sessionId)
  const logExport = useLogExport()

  const exportReport = () => {
    if (!report.data) return
    logExport.mutate({ cohortId, kind: 'session_report' })
    downloadCsv(
      'session-report.csv',
      report.data.map(r => ({
        student: r.roster_name,
        score: r.score,
        correct: r.correct_count,
        answered: r.answered,
      })),
    )
  }

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          What to reteach
        </h2>
        {stats.isPending ? <Spinner /> : null}
        {stats.data ? (
          <ol className="flex flex-col gap-2 text-sm">
            {stats.data.map(s => (
              <li key={s.question_id} className="flex justify-between gap-3">
                <span className="max-w-xl truncate" title={s.stem}>
                  {s.stem}
                </span>
                <span
                  className={`font-medium ${s.correct_rate < 0.6 ? 'text-red-700' : 'text-slate-500'}`}
                >
                  {Math.round(s.correct_rate * 100)}% correct
                </span>
              </li>
            ))}
          </ol>
        ) : null}
      </Card>
      <Card>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-900">
            Student report
          </h2>
          {report.data ? (
            <Button variant="ghost" onClick={exportReport}>
              Export CSV
            </Button>
          ) : null}
        </div>
        {report.error ? (
          <Alert tone="info">{report.error.message}</Alert>
        ) : null}
        {report.data ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <caption className="sr-only">Per-student session report</caption>
              <thead>
                <tr className="border-b border-slate-200 text-left text-xs text-slate-500">
                  <th scope="col" className="py-2 pr-3 font-medium">Student</th>
                  <th scope="col" className="py-2 pr-3 font-medium">Score</th>
                  <th scope="col" className="py-2 font-medium">Correct</th>
                </tr>
              </thead>
              <tbody>
                {report.data.map(r => (
                  <tr key={r.student_ref} className="border-b border-slate-100">
                    <td className="py-2 pr-3">{r.roster_name}</td>
                    <td className="py-2 pr-3 tabular-nums">{r.score}</td>
                    <td className="py-2 tabular-nums">
                      {r.correct_count}/{r.answered}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </Card>
    </div>
  )
}

export function LiveRunner({
  cohortId,
  sessionId,
}: {
  cohortId: string
  sessionId: string
}) {
  const meta = useLiveSessionMeta(sessionId)
  const { state, error } = useLiveSession(sessionId)
  const advance = useAdvanceLiveSession()
  const end = useEndLiveSession()

  if (meta.isPending) return <Spinner label="Loading session" />
  if (meta.error) return <Alert tone="error">{meta.error.message}</Alert>
  if (!meta.data) return null

  const status = state?.status ?? meta.data.status

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div>
          <a href={`#/class/${cohortId}`} className="text-sm text-slate-500 hover:underline">
            Back to class
          </a>
          <h1 className="text-xl font-semibold text-slate-900">
            {meta.data.title}
          </h1>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone={status === 'ended' ? 'slate' : 'green'}>{status}</Badge>
          {status !== 'ended' ? (
            <>
              <Button
                onClick={() => advance.mutate({ sessionId })}
                disabled={advance.isPending}
              >
                {status === 'lobby'
                  ? 'Start'
                  : status === 'question'
                    ? 'Reveal'
                    : 'Next question'}
              </Button>
              <Button
                variant="danger"
                onClick={() => end.mutate({ sessionId })}
                disabled={end.isPending}
              >
                End session
              </Button>
            </>
          ) : null}
        </div>
      </div>

      {error ? <Alert tone="error">{error}</Alert> : null}

      {status === 'lobby' ? (
        <Lobby
          sessionId={sessionId}
          code={meta.data.join_code}
          onStart={() => advance.mutate({ sessionId })}
          starting={advance.isPending}
        />
      ) : null}

      {status === 'question' && state?.question ? (
        <Card>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-sm text-slate-500">
              Question {(state.index ?? 0) + 1} of {state.total}
            </span>
            <Countdown
              startedAt={state.started_at}
              questionSeconds={state.question_seconds ?? meta.data.question_seconds}
            />
          </div>
          <p className="text-lg font-medium text-slate-900">
            {state.question.stem}
          </p>
          <ul className="mt-3 grid gap-2 sm:grid-cols-2">
            {state.question.options.map(o => (
              <li
                key={o.key}
                className="rounded-md border border-slate-200 px-3 py-2 text-sm"
              >
                <span className="mr-2 font-semibold">{o.key.toUpperCase()}</span>
                {o.text}
              </li>
            ))}
          </ul>
        </Card>
      ) : null}

      {status === 'reveal' ? (
        <RevealPanel sessionId={sessionId} index={state?.index ?? 0} />
      ) : null}

      {status === 'ended' ? (
        <EndedPanel cohortId={cohortId} sessionId={sessionId} />
      ) : null}
    </div>
  )
}
