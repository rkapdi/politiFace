import { useState, type FormEvent } from 'react'
import { useJoinClass, useMyStudentClasses } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card, Spinner } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

export function StudentHome() {
  const classes = useMyStudentClasses()
  const joinClass = useJoinClass()
  const [sessionCode, setSessionCode] = useState('')
  const [classCode, setClassCode] = useState('')
  const [rosterName, setRosterName] = useState('')

  const goToSession = (e: FormEvent) => {
    e.preventDefault()
    window.location.hash = `#/join?code=${sessionCode.trim().toUpperCase()}`
  }
  const onJoinClass = (e: FormEvent) => {
    e.preventDefault()
    joinClass.mutate({ code: classCode.trim().toUpperCase(), rosterName: rosterName.trim() })
  }

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-4">
      <Card>
        <h1 className="mb-2 text-sm font-semibold text-slate-900">{S.student.title}</h1>
        {classes.isPending ? <Spinner /> : null}
        {classes.data && classes.data.length === 0 ? (
          <p className="text-sm text-slate-500">{S.student.none}</p>
        ) : null}
        <ul className="flex flex-col divide-y divide-slate-100">
          {(classes.data ?? []).map(c => (
            <li key={c.cohort_id} className="flex items-center justify-between py-2">
              <div>
                <p className="text-sm font-medium text-slate-900">{c.name}</p>
                <p className="text-xs text-slate-500">
                  {c.professor}{c.roster_name ? `, you are listed as ${c.roster_name}` : ''}
                </p>
              </div>
              {c.term ? <Badge>{c.term}</Badge> : null}
            </li>
          ))}
        </ul>
      </Card>
      <Card>
        <h2 className="mb-2 text-sm font-semibold text-slate-900">{S.student.joinSession}</h2>
        <form onSubmit={goToSession} className="flex items-end gap-2">
          <label className="flex-1 text-sm text-slate-700">
            {S.student.sessionCode}
            <input required value={sessionCode}
              onChange={e => setSessionCode(e.target.value.toUpperCase())}
              className={`${field} font-semibold tracking-[0.3em] uppercase`} />
          </label>
          <Button type="submit">{S.student.join}</Button>
        </form>
      </Card>
      <Card>
        <h2 className="mb-2 text-sm font-semibold text-slate-900">{S.student.joinClass}</h2>
        <form onSubmit={onJoinClass} className="flex flex-col gap-3">
          <label className="text-sm text-slate-700">
            {S.student.classCode}
            <input required value={classCode}
              onChange={e => setClassCode(e.target.value.toUpperCase())}
              className={`${field} uppercase`} />
          </label>
          <label className="text-sm text-slate-700">
            {S.student.rosterName}
            <input required minLength={2} maxLength={60} value={rosterName}
              onChange={e => setRosterName(e.target.value)} className={field} />
          </label>
          {joinClass.error ? <Alert tone="error">{joinClass.error.message}</Alert> : null}
          {joinClass.isSuccess ? <Alert tone="success">{S.student.joined}</Alert> : null}
          <div><Button type="submit" disabled={joinClass.isPending}>{S.student.join}</Button></div>
        </form>
      </Card>
      <p className="text-center text-sm text-slate-500">{S.student.getApp}</p>
    </div>
  )
}
