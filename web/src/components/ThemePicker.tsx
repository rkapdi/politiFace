import { S } from '../lib/strings'
import { useTheme, type Theme } from '../lib/theme'

// Fixed preview colours: each card shows its own theme whichever one is active.
const OPTIONS: { id: Theme; name: string; hint: string; swatch: [string, string, string] }[] = [
  { id: 'dark', name: S.theme.dark, hint: S.theme.darkHint, swatch: ['#141414', '#1d1d1d', '#8fe3b0'] },
  { id: 'light', name: S.theme.light, hint: S.theme.lightHint, swatch: ['#f3f2ef', '#ffffff', '#ffd400'] },
]

export function ThemePicker() {
  const [theme, setTheme] = useTheme()
  return (
    <div role="group" aria-label={S.theme.heading} className="grid gap-3 sm:grid-cols-2">
      {OPTIONS.map(o => (
        <button
          key={o.id}
          type="button"
          aria-pressed={theme === o.id}
          onClick={() => setTheme(o.id)}
          className="flex flex-col gap-3 rounded-lg border-[1.5px] border-transparent bg-raised p-3.5 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus aria-pressed:border-ink"
        >
          <span
            aria-hidden="true"
            className="flex h-20 gap-1.5 rounded-md p-2"
            style={{ background: o.swatch[0] }}
          >
            <span className="w-[14%] rounded-sm" style={{ background: o.swatch[1] }} />
            <span className="w-[30%] rounded-sm" style={{ background: o.swatch[2] }} />
            <span className="flex-1 rounded-sm" style={{ background: o.swatch[1] }} />
          </span>
          <span>
            <span className="block text-sm font-bold text-ink">{o.name}</span>
            <span className="block text-[13px] text-ink-3">{o.hint}</span>
          </span>
        </button>
      ))}
    </div>
  )
}
