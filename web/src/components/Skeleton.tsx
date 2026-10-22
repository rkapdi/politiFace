// Skeletons shaped like the content they replace, so real data lands
// without layout shift. Every variant reserves the final height.

function Block({ className }: { className: string }) {
  return <div aria-hidden="true" className={`animate-pulse rounded bg-line ${className}`} />
}

function Busy({ children }: { children: React.ReactNode }) {
  return (
    <div role="status" aria-busy="true" aria-label="Loading">
      {children}
    </div>
  )
}

export function SkeletonStats({ count = 4 }: { count?: number }) {
  return (
    <Busy>
      <div
        className="grid grid-cols-2 gap-4 sm:grid-cols-4"
        style={{ gridTemplateColumns: undefined }}
      >
        {Array.from({ length: count }, (_, i) => (
          <div key={i} className="rounded-lg border border-line bg-white p-4">
            <Block className="h-3 w-20" />
            <Block className="mt-3 h-7 w-14" />
          </div>
        ))}
      </div>
    </Busy>
  )
}

export function SkeletonTable({ rows = 6 }: { rows?: number }) {
  return (
    <Busy>
      <div className="rounded-lg border border-line bg-white p-4">
        <Block className="mb-4 h-4 w-48" />
        {Array.from({ length: rows }, (_, i) => (
          <div key={i} className="flex items-center gap-4 border-b border-line/60 py-2.5">
            <Block className="h-4 w-32" />
            <Block className="h-4 w-16" />
            <Block className="h-4 w-24" />
            <Block className="ml-auto h-4 w-12" />
          </div>
        ))}
      </div>
    </Busy>
  )
}

export function SkeletonChart({ height = 'h-44' }: { height?: string }) {
  return (
    <Busy>
      <div className="rounded-lg border border-line bg-white p-4">
        <Block className="mb-3 h-4 w-40" />
        <Block className={`w-full ${height}`} />
      </div>
    </Busy>
  )
}
