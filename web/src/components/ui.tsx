import type { ButtonHTMLAttributes, HTMLAttributes, ReactNode } from 'react'
import * as RadixTabs from '@radix-ui/react-tabs'

type ButtonVariant = 'primary' | 'ghost' | 'danger'

const buttonStyles: Record<ButtonVariant, string> = {
  primary:
    'bg-slate-900 text-white hover:bg-slate-700 disabled:bg-slate-300 disabled:text-slate-500',
  ghost:
    'bg-transparent text-slate-700 hover:bg-slate-100 border border-slate-300 disabled:text-slate-400',
  danger:
    'bg-red-700 text-white hover:bg-red-600 disabled:bg-red-200 disabled:text-red-400',
}

export function Button({
  variant = 'primary',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant }) {
  return (
    <button
      className={`inline-flex items-center gap-2 rounded-md px-3.5 py-2 text-sm font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900 disabled:cursor-not-allowed ${buttonStyles[variant]} ${className}`}
      {...props}
    />
  )
}

export function Card({
  className = '',
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-lg border border-slate-200 bg-white p-4 shadow-sm ${className}`}
      {...props}
    />
  )
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
      <div className="text-sm text-slate-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-slate-900">{value}</div>
      {hint ? <div className="mt-1 text-xs text-slate-400">{hint}</div> : null}
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
  const tones = {
    slate: 'bg-slate-100 text-slate-700',
    green: 'bg-pass-soft text-pass',
    amber: 'bg-borderline-soft text-borderline',
    red: 'bg-risk-soft text-risk',
  }
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${tones[tone]}`}
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
    error: 'border-risk/30 bg-risk-soft text-risk',
    success: 'border-pass/30 bg-pass-soft text-pass',
    info: 'border-slate-300 bg-slate-50 text-slate-700',
  }
  return (
    <div
      role={tone === 'error' ? 'alert' : 'status'}
      className={`rounded-md border px-3 py-2 text-sm ${tones[tone]}`}
    >
      {children}
    </div>
  )
}

export function Spinner({ label = 'Loading' }: { label?: string }) {
  return (
    <div aria-busy="true" role="status" className="flex items-center gap-2 p-4 text-slate-500">
      <span className="size-4 animate-spin rounded-full border-2 border-slate-300 border-t-slate-900" />
      <span className="text-sm">{label}</span>
    </div>
  )
}

export const Tabs = RadixTabs.Root

export function TabsList(props: RadixTabs.TabsListProps) {
  return (
    <RadixTabs.List
      className="mb-4 flex gap-1 border-b border-slate-200"
      {...props}
    />
  )
}

export function TabsTrigger(props: RadixTabs.TabsTriggerProps) {
  return (
    <RadixTabs.Trigger
      className="rounded-t-md px-3.5 py-2 text-sm font-medium text-slate-500 transition-colors hover:text-slate-900 focus-visible:outline-2 focus-visible:outline-offset--2 focus-visible:outline-slate-900 data-[state=active]:border-b-2 data-[state=active]:border-slate-900 data-[state=active]:text-slate-900"
      {...props}
    />
  )
}

export const TabsContent = RadixTabs.Content
