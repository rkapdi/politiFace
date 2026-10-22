// Pure helpers for live-session scoring options (no I/O).

// Blank means no goal. Anything else must be a whole number 1 to 100.
export function parseGoal(raw: string): number | null {
  const t = raw.trim()
  if (t === '' || !/^\d+$/.test(t)) return null
  const n = Number(t)
  return n >= 1 && n <= 100 ? n : null
}

// Whole-number percent of answers that were correct, or null when nobody
// answered. Derived from live_reveal counts.
export function classPercentCorrect(
  counts: Record<string, number>,
  correctKey: string,
): number | null {
  const total = Object.values(counts).reduce((a, b) => a + b, 0)
  if (total === 0) return null
  return Math.round(((counts[correctKey] ?? 0) * 100) / total)
}
