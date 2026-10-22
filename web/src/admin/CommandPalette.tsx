import { useEffect, useRef, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
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
        className="flex-1 border border-[var(--a-line)] px-2 py-1 text-left text-[var(--a-muted)]"
      >
        {A.searchHint} {A.searchPlaceholder}
      </button>
      {open ? (
        <div
          ref={dialogRef}
          role="dialog"
          aria-modal="true"
          aria-label={A.titles.search}
          className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-24"
          onClick={close}
          onKeyDown={trapTab}
        >
          <div
            className="admin-panel w-[min(640px,92vw)] p-2"
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
              className="w-full border border-[var(--a-line)] bg-[var(--a-bg)] px-2 py-1.5 text-[var(--a-strong)]"
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
