// Compact, safe rendering for a timeline/audit "detail(s)" payload that is a
// plain object (never an array, never HTML): "key: value · key: value",
// each value stringified and truncated so one oversized field cannot blow
// up a row. Returns null for anything else (strings render as-is by the
// caller; empty objects and arrays render nothing).
export function formatDetailObject(value: unknown): string | null {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return null
  const entries = Object.entries(value as Record<string, unknown>)
  if (entries.length === 0) return null
  return entries.map(([k, v]) => `${k}: ${String(v).slice(0, 120)}`).join(' · ')
}
