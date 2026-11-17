import type { ReactNode } from 'react'
import { Moon, Sun } from 'lucide-react'
import { S } from '../lib/strings'
import { useTheme } from '../lib/theme'

export function BrandMark({ size = 32 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 28 28" fill="none" aria-hidden="true" className="shrink-0">
      <rect width="28" height="28" rx="9" fill="var(--color-cta)" />
      <path d="M8.5 21.5V6.5h7.6l3.9 3.7v5l-2.6 2H12v4.3H8.5z" fill="var(--color-on-cta)" />
      <path d="M12 9.8h3.3c.4 1 .8 1.6 1.4 2.4-.4.3-.6.6-.6 1l-1 1H12V9.8z" fill="var(--color-cta)" />
    </svg>
  )
}

/** Icon-only, so the label is both screen-reader text and a hover title. */
export function ThemeToggle({ className }: { className: string }) {
  const [theme, setTheme] = useTheme()
  const label = theme === 'dark' ? S.theme.toLight : S.theme.toDark
  const Icon = theme === 'dark' ? Sun : Moon
  return (
    <button
      type="button"
      className={className}
      title={label}
      onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
    >
      <Icon aria-hidden="true" className="size-[18px]" strokeWidth={1.6} />
      <span className="sr-only">{label}</span>
    </button>
  )
}

/** Pages outside the console shell: sign in, join a session, instructor invite. */
export function PublicPage({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col p-3">
      <header className="flex min-h-[60px] items-center justify-between px-2 print:hidden">
        <span className="inline-flex items-center gap-2.5 text-[17px] font-extrabold tracking-tight text-ink">
          <BrandMark />
          Politiface
        </span>
        <ThemeToggle className="flex size-9 items-center justify-center rounded-full bg-control text-ink-2 hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus" />
      </header>
      <main className="mx-auto flex w-full max-w-md flex-col gap-3 px-1 pb-16 pt-[4vh]">
        {children}
      </main>
    </div>
  )
}
