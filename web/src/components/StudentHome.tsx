import { useState, type FormEvent } from 'react'
import { liveSessionPreview, useJoinClass, useMyStudentClasses } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Badge, Button, Card, Spinner } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

// A student holds "a code from the professor" and should not have to know
// which kind it is. A running session wins; anything else is treated as a
// class code, which needs a roster name (there is no way to check a class
// code without joining, so a typo surfaces on that step).
function CodeCard({ knownName }: { knownName: string }) {
  const joinClass = useJoinClass()
  const [code, setCode] = useState('')
  const [name, setName] = useState<string | null>(null)
  const [checking, setChecking] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const askingName = name !== null
  const cleanCode = code.trim().toUpperCase()

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError(null)
    if (askingName) {
      joinClass.mutate(
        { code: cleanCode, rosterName: name.trim() },
        {
          onSuccess: () => {
            setCode('')
            setName(null)
          },
        },
      )
      return
    }
    joinClass.reset()
    setChecking(true)
    try {
      await liveSessionPreview(cleanCode)
      window.location.hash = `#/join?code=${encodeURIComponent(cleanCode)}`
    } catch (err) {
      if ((err as Error).message === S.errors.badSessionCode) setName(knownName)
      else setError((err as Error).message)
    } finally {
      setChecking(false)
    }
  }

  return (
    <Card>
      <h2 className="text-sm font-semibold text-slate-900">{S.student.enterCode}</h2>
      <p className="mb-2 text-xs text-slate-500">{S.student.enterCodeHint}</p>
      <form onSubmit={e => void onSubmit(e)} className="flex flex-col gap-3">
        <label className="text-sm text-slate-700">
          {S.student.code}
          <input
            required
            autoComplete="off"
            value={code}
            onChange={e => {
              setCode(e.target.value.toUpperCase())
              setName(null)
              setError(null)
            }}
            className={`${field} font-semibold tracking-[0.3em] uppercase`}
          />
        </label>
        {askingName ? (
          <label className="text-sm text-slate-700">
            {S.student.rosterName}
            <input
              required
              autoFocus
              minLength={2}
              maxLength={60}
              autoComplete="name"
              value={name}
              onChange={e => setName(e.target.value)}
              className={field}
            />
          </label>
        ) : null}
        {error ? <Alert tone="error">{error}</Alert> : null}
        {joinClass.error ? <Alert tone="error">{joinClass.error.message}</Alert> : null}
        {joinClass.isSuccess ? <Alert tone="success">{S.student.joined}</Alert> : null}
        <div>
          <Button type="submit" disabled={checking || joinClass.isPending}>
            {askingName ? S.student.joinClassButton : S.student.continue}
          </Button>
        </div>
      </form>
    </Card>
  )
}

export function StudentHome() {
  const classes = useMyStudentClasses()

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
      <CodeCard knownName={classes.data?.find(c => c.roster_name)?.roster_name ?? ''} />
      <p className="text-center text-sm text-slate-500">
        {S.student.getAppPre}{' '}
        <a
          href="https://politiface.app/"
          className="font-medium text-slate-900 underline"
        >
          {S.student.getAppLink}
        </a>
        {S.student.getAppPost}
      </p>
    </div>
  )
}
