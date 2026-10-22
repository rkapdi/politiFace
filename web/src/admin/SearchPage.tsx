import { useState } from 'react'
import { Link } from '@tanstack/react-router'
import { hitPath, useAdminSearch } from './adminApi'
import { useDebounced } from './useDebounced'
import { A } from './strings'

export function SearchPage() {
  const [q, setQ] = useState('')
  const debouncedQ = useDebounced(q, 200)
  const hits = useAdminSearch(debouncedQ).data ?? []
  return (
    <div className="flex flex-col gap-2">
      <h1 className="admin-strong">{A.titles.search}</h1>
      <input
        type="search"
        aria-label={A.searchPlaceholder}
        placeholder={A.searchPlaceholder}
        value={q}
        onChange={e => setQ(e.target.value)}
        className="admin-panel px-2 py-1.5 text-[var(--a-strong)]"
      />
      <ul className="admin-panel p-2">
        {hits.map(h => (
          <li key={`${h.kind}-${h.id}`}>
            <Link to={hitPath(h) as never}>
              <span className="admin-label mr-2">{h.kind}</span>
              {h.title}
            </Link>{' '}
            <span className="text-[var(--a-muted)]">{h.subtitle}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
