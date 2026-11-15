import type { ButtonHTMLAttributes, HTMLAttributes, ReactNode } from 'react'
import * as RadixTabs from '@radix-ui/react-tabs'
import { Check, Info, TriangleAlert } from 'lucide-react'

// Shared primitives. Colours are role tokens from styles.css, so every
// component here works in both themes.

type ButtonVariant = 'primary' | 'ghost' | 'danger'

const buttonStyles: Record<ButtonVariant, string> = {
  primary: 'bg-cta text-on-cta hover:brightness-95',
  ghost: 'bg-control text-ink hover:bg-line-strong',
  // Destructive actions are outlined, not red: red is not a UI colour here.
  danger: 'bg-transparent text-risk ring-[1.5px] ring-inset ring-risk hover:bg-control',
}

/** Text every input, select and textarea shares. */
export const fieldClass =
  'rounded-md border border-field-line bg-field px-3 py-2 text-sm text-ink placeholder:text-ink-3 focus-visible:outline-2 focus-visible:outline-focus'

export function Button({
  variant = 'primary',
  shape = 'pill',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant
  /** `block` is for buttons that hold wrapping text, such as answer options. */
  shape?: 'pill' | 'block'
}) {
  const justify = /\bjustify-/.test(className) ? '' : 'justify-center'
  return (
    <button
      className={`inline-flex items-center ${justify} gap-2 px-4 py-2 text-sm font-bold transition-[filter,background-color] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus disabled:cursor-not-allowed disabled:opacity-50 ${
        shape === 'pill' ? 'rounded-full' : 'rounded-lg'
      } ${buttonStyles[variant]} ${className}`}
      {...props}
    />
  )
}

export function Card({
  className = '',
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return <div className={`rounded-xl bg-panel p-5 ${className}`} {...props} />
}

export function Stat({
  label,
  value,
  hint,
}: {
  label: string
  value: ReactNode
  hint?: string
}) {
  return (
    <Card>
      <div className="text-[13px] font-semibold text-ink-3">{label}</div>
      <div className="mt-1 text-[26px] font-bold leading-8 tracking-tight text-ink tabular-nums">
        {value}
      </div>
      {hint ? <div className="mt-0.5 text-xs text-ink-2">{hint}</div> : null}
    </Card>
  )
}

export function Badge({
  children,
  tone = 'slate',
}: {
  children: ReactNode
  tone?: 'slate' | 'green' | 'amber' | 'red'
}) {
  // The lowest band is outlined as well as tinted, so it never reads by
  // colour alone.
  const tones = {
    slate: 'bg-control text-ink-2',
    green: 'bg-pass-soft text-pass',
    amber: 'bg-borderline-soft text-borderline',
    red: 'bg-risk-soft text-risk ring-[1.5px] ring-inset ring-risk-line',
  }
  return (
    <span
      className={`inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${tones[tone]}`}
    >
      {children}
    </span>
  )
}

export function Alert({
  children,
  tone = 'error',
}: {
  children: ReactNode
  tone?: 'error' | 'success' | 'info'
}) {
  const tones = {
    error: 'bg-risk-soft text-ink ring-[1.5px] ring-inset ring-risk-line',
    success: 'bg-raised text-ink',
    info: 'bg-raised text-ink-2',
  }
  const Icon = tone === 'error' ? TriangleAlert : tone === 'success' ? Check : Info
  return (
    <div
      role={tone === 'error' ? 'alert' : 'status'}
      className={`flex items-start gap-2.5 rounded-md px-3.5 py-3 text-sm font-medium ${tones[tone]}`}
    >
      <Icon
        aria-hidden="true"
        className={`mt-0.5 size-4 shrink-0 ${
          tone === 'error' ? 'text-risk' : tone === 'success' ? 'text-pass' : 'text-ink-3'
        }`}
      />
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  )
}

export function Spinner({ label = 'Loading' }: { label?: string }) {
  return (
    <div aria-busy="true" role="status" className="flex items-center gap-2 p-4 text-ink-3">
      <span className="size-4 animate-spin rounded-full border-2 border-control border-t-ink" />
      <span className="text-sm">{label}</span>
    </div>
  )
}

export const Tabs = RadixTabs.Root

export function TabsList(props: RadixTabs.TabsListProps) {
  return (
    <RadixTabs.List
      className="inline-flex max-w-full gap-0.5 overflow-x-auto rounded-full bg-panel p-1"
      {...props}
    />
  )
}

export function TabsTrigger(props: RadixTabs.TabsTriggerProps) {
  return (
    <RadixTabs.Trigger
      className="whitespace-nowrap rounded-full px-3.5 py-1.5 text-[13px] font-semibold text-ink-2 transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus data-[state=active]:bg-strong data-[state=active]:font-bold data-[state=active]:text-on-strong"
      {...props}
    />
  )
}

export const TabsContent = RadixTabs.Content
