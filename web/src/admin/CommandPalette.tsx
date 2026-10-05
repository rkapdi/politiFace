import { useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { useAdminSearch, type SearchHit } from './adminApi'
import { A } from './strings'

// oxlint-disable-next-line react/only-export-components -- shared with SearchPage
export function hitPath(h: SearchHit): string {
  if (h.kind === 'person') return `/admin/people/${h.id}`
  if (h.kind === 'class') return `/admin/classes/${h.id}`
  return `/admin/sessions/${h.id}`
}

/** Cmd-K / Ctrl-K: search everything, Enter opens the first hit. */
export function CommandPalette() {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const navigate = useNavigate()
  const hits = useAdminSearch(q).data ?? []

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setOpen(o => !o)
      }
      if (e.key === 'Escape') setOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const go = (h: SearchHit) => {
    setOpen(false)
    setQ('')
    void navigate({ to: hitPath(h) as never })
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex-1 border border-[var(--a-line)] px-2 py-1 text-left text-[var(--a-muted)]"
      >
        {A.searchHint} {A.searchPlaceholder}
      </button>
      {open ? (
        <div
          role="dialog"
          aria-label={A.titles.search}
          className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-24"
          onClick={() => setOpen(false)}
        >
          <div
            className="admin-panel w-[min(640px,92vw)] p-2"
            onClick={e => e.stopPropagation()}
          >
            <input
              role="combobox"
              aria-expanded={hits.length > 0}
              aria-label={A.searchPlaceholder}
              autoFocus
              value={q}
              onChange={e => setQ(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && hits[0]) go(hits[0])
              }}
              placeholder={A.searchPlaceholder}
              className="w-full border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1.5 text-[var(--a-strong)]"
            />
            <ul className="mt-2 max-h-80 overflow-y-auto">
              {q.trim().length >= 2 && hits.length === 0 ? (
                <li className="px-2 py-1 text-[var(--a-muted)]">{A.noHits}</li>
              ) : null}
              {hits.slice(0, 8).map(h => (
                <li key={`${h.kind}-${h.id}`}>
                  <button
                    type="button"
                    onClick={() => go(h)}
                    className="flex w-full gap-2 px-2 py-1 text-left hover:bg-[var(--a-line)]"
                  >
                    <span className="admin-label w-16">{h.kind}</span>
                    <span className="admin-strong">{h.title}</span>
                    <span className="text-[var(--a-muted)]">{h.subtitle}</span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>
      ) : null}
    </>
  )
}
