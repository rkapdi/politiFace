import { useEffect, useState, type FormEvent } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useMyAccessRequest, useRequestFacultyAccess } from '../lib/api'
import { S } from '../lib/strings'
import { Alert, Button, Card, Spinner } from './ui'

const field = 'mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm'

export function RequestAccess() {
  const queryClient = useQueryClient()
  const request = useMyAccessRequest()
  const submit = useRequestFacultyAccess()
  const [school, setSchool] = useState('')
  const [courses, setCourses] = useState('')
  const [note, setNote] = useState('')
  const status = request.data?.status

  // Approval happens elsewhere (the request poll picks it up); once it
  // lands, re-resolve the home so the faculty console appears.
  useEffect(() => {
    if (status === 'approved') {
      void queryClient.invalidateQueries({ queryKey: ['console-role'] })
    }
  }, [status, queryClient])

  if (request.isPending) return <Spinner />

  const onSubmit = (e: FormEvent) => {
    e.preventDefault()
    submit.mutate({ school: school.trim(), courses: courses.trim(), note: note.trim() })
  }

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-4">
      <Card>
        <h1 className="text-lg font-semibold text-slate-900">{S.requestAccess.title}</h1>
        <p className="mt-1 text-sm text-slate-600">{S.requestAccess.intro}</p>
        {status === 'pending' ? (
          <div className="mt-3">
            <Alert tone="info">{S.requestAccess.pending}</Alert>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="mt-3 flex flex-col gap-3">
            {status === 'denied' ? <Alert tone="error">{S.requestAccess.denied}</Alert> : null}
            <label className="text-sm text-slate-700">
              {S.requestAccess.school}
              <input required minLength={2} maxLength={120} value={school}
                onChange={e => setSchool(e.target.value)} className={field} />
            </label>
            <label className="text-sm text-slate-700">
              {S.requestAccess.courses}
              <input required minLength={2} maxLength={200} value={courses}
                placeholder={S.requestAccess.coursesPlaceholder}
                onChange={e => setCourses(e.target.value)} className={field} />
            </label>
            <label className="text-sm text-slate-700">
              {S.requestAccess.note}
              <textarea rows={2} maxLength={500} value={note}
                onChange={e => setNote(e.target.value)} className={field} />
            </label>
            {submit.error ? <Alert tone="error">{submit.error.message}</Alert> : null}
            <div>
              <Button type="submit" disabled={submit.isPending}>{S.requestAccess.submit}</Button>
            </div>
          </form>
        )}
      </Card>
      <p className="text-center text-sm text-slate-500">
        {S.requestAccess.studentInstead}{' '}
        <a href="#/join" className="font-medium text-slate-900 underline">{S.student.joinSession}</a>
      </p>
    </div>
  )
}
