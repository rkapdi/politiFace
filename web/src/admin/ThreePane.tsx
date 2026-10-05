import type { ReactNode } from 'react'

/** Linked records left, timeline center, facts and actions right. */
export function ThreePane({
  header,
  left,
  center,
  right,
}: {
  header: ReactNode
  left: ReactNode
  center: ReactNode
  right: ReactNode
}) {
  return (
    <div className="flex flex-col gap-2">
      <div className="admin-panel flex flex-wrap items-baseline gap-3 px-3 py-2">{header}</div>
      <div className="grid gap-2 lg:grid-cols-[220px_1fr_260px]">
        <aside className="admin-panel p-2" aria-label="Linked records">{left}</aside>
        <section className="admin-panel p-2" aria-label="Timeline">{center}</section>
        <aside className="admin-panel p-2" aria-label="Properties and actions">{right}</aside>
      </div>
    </div>
  )
}
