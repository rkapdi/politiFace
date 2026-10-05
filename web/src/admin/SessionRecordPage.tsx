import { Link, useParams } from '@tanstack/react-router'
import { useAdminSession } from './adminApi'
import { ThreePane } from './ThreePane'
import { Timeline } from './Timeline'
import { A } from './strings'

export function SessionRecordPage() {
  const { sessionId } = useParams({ strict: false }) as { sessionId: string }
  const rec = useAdminSession(sessionId)
  if (rec.isPending) return <p>{A.loading}</p>
  if (rec.error || !rec.data) return <p className="sev-fail">{rec.error?.message}</p>
  const s = rec.data
  return (
    <ThreePane
      header={
        <>
          <span className="admin-label">Session</span>
          <h1 className="admin-strong text-sm font-bold">{s.facts.title}</h1>
          <Link to="/admin/classes/$cohortId" params={{ cohortId: s.facts.cohort_id }}>{s.facts.class}</Link>
          <span className="flex-1" />
          <span className={s.facts.status === 'ended' ? 'text-[var(--a-muted)]' : 'sev-ok'}>
            {s.facts.status.toUpperCase()} · Q{s.facts.index + 1}/{s.facts.total}
          </span>
        </>
      }
      left={
        <>
          <div className="admin-label">Participants ({s.participants.length})</div>
          {s.participants.map(p => (
            <div key={p.user_id}>
              {p.is_guest ? (
                <span>▸ {p.name} (guest)</span>
              ) : (
                <Link to="/admin/people/$userId" params={{ userId: p.user_id }}>▸ {p.name}</Link>
              )}
              <div className="pl-3 text-[var(--a-muted)]">{p.correct}/{p.answered} correct</div>
            </div>
          ))}
        </>
      }
      center={<Timeline entries={s.timeline} />}
      right={
        <>
          <div className="admin-label">Properties</div>
          <div>professor {s.facts.professor ?? 'unknown'}</div>
          <div>code {s.facts.join_code}</div>
          <div>{s.facts.question_seconds}s per question</div>
          <div>guests {s.facts.allow_guests ? 'allowed' : 'off'}</div>
          <div className="admin-label mt-3">Questions</div>
          {s.questions.map(q => (
            <div key={q.question_id} className="mb-1">
              <div>{q.position}. {q.stem}</div>
              <div className="text-[var(--a-muted)]">
                {q.answered} answered · {q.correct_rate == null ? 'n/a' : `${Math.round(q.correct_rate * 100)}%`} correct
              </div>
            </div>
          ))}
        </>
      }
    />
  )
}
