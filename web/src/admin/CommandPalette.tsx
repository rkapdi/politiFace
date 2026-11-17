import { useEffect, useRef, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Search } from 'lucide-react'
import { fieldClass } from '../components/ui'
import { hitPath, useAdminSearch, type SearchHit } from './adminApi'
import { useDebounced } from './useDebounced'
import { A } from './strings'

/** Cmd-K / Ctrl-K: search everything, Enter opens the first hit. */
export function CommandPalette() {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const debouncedQ = useDebounced(q, 200)
  const navigate = useNavigate()
  const hits = useAdminSearch(debouncedQ).data ?? []

  const triggerRef = useRef<HTMLButtonElement>(null)
  const dialogRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([])

  // Global Cmd-K / Ctrl-K opens the palette from anywhere in the console.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setOpen(o => !o)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  // Focus moves into the dialog when it opens; nothing to do on close,
  // `close()` below returns it to the trigger explicitly.
  useEffect(() => {
    if (open) inputRef.current?.focus()
  }, [open])

  const close = () => {
    setOpen(false)
    setQ('')
    triggerRef.current?.focus()
  }

  const go = (h: SearchHit) => {
    close()
    void navigate({ to: hitPath(h) as never })
  }

  const trapTab = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault()
      close()
      return
    }
    if (e.key !== 'Tab') return
    const focusables = dialogRef.current?.querySelectorAll<HTMLElement>('input, button')
    if (!focusables || focusables.length === 0) return
    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault()
      first.focus()
    }
  }

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen(true)}
        className="flex h-11 min-w-[220px] flex-1 items-center gap-2.5 bg-panel px-4 text-left text-[13px] font-medium text-ink-3 hover:text-ink-2"
      >
        <Search aria-hidden="true" className="size-4 shrink-0" strokeWidth={1.6} />
        <span className="min-w-0 flex-1 truncate">{A.searchPlaceholder}</span>
        <kbd className="shrink-0 rounded-sm bg-control px-1.5 py-0.5 font-mono text-[11px] text-ink-2">
          {A.searchHint}
        </kbd>
      </button>
      {open ? (
        <div
          ref={dialogRef}
          role="dialog"
          aria-modal="true"
          aria-label={A.titles.search}
          className="fixed inset-0 z-50 flex items-start justify-center bg-scrim pt-24"
          onClick={close}
          onKeyDown={trapTab}
        >
          <div
            className="w-[min(640px,92vw)] rounded-xl bg-pop p-3 shadow-pop"
            onClick={e => e.stopPropagation()}
          >
            <input
              ref={inputRef}
              type="search"
              aria-label={A.searchPlaceholder}
              value={q}
              onChange={e => setQ(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && hits[0]) go(hits[0])
                else if (e.key === 'ArrowDown') {
                  e.preventDefault()
                  itemRefs.current[0]?.focus()
                }
              }}
              placeholder={A.searchPlaceholder}
              className={`w-full ${fieldClass}`}
            />
            <ul className="mt-2 max-h-80 overflow-y-auto">
              {q.trim().length >= 2 && hits.length === 0 ? (
                <li className="px-2 py-1 text-[var(--a-muted)]">{A.noHits}</li>
              ) : null}
              {hits.slice(0, 8).map((h, i) => (
                <li key={`${h.kind}-${h.id}`}>
                  <button
                    ref={el => {
                      itemRefs.current[i] = el
                    }}
                    type="button"
                    onClick={() => go(h)}
                    onKeyDown={e => {
                      if (e.key === 'ArrowDown') {
                        e.preventDefault()
                        itemRefs.current[i + 1]?.focus()
                      } else if (e.key === 'ArrowUp') {
                        e.preventDefault()
                        if (i === 0) inputRef.current?.focus()
                        else itemRefs.current[i - 1]?.focus()
                      }
                    }}
                    className="flex w-full items-baseline gap-2 rounded-md px-2 py-1.5 text-left hover:bg-control"
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
