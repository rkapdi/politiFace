// Recharts draws axis text, grid lines and tooltips with its own light
// defaults. These props point them at the role tokens instead, so charts
// follow the theme.
export const axisTick = (fontSize: number) => ({ fontSize, fill: 'var(--color-ink-3)' })

export const axisLine = {
  axisLine: { stroke: 'var(--color-line-strong)' },
  tickLine: { stroke: 'var(--color-line-strong)' },
}

export const tooltipStyle = {
  cursor: { fill: 'var(--color-control)', stroke: 'var(--color-line-strong)' },
  contentStyle: {
    background: 'var(--color-pop)',
    border: '1px solid var(--color-line-strong)',
    borderRadius: 12,
    color: 'var(--color-ink)',
    fontSize: 12,
  },
  labelStyle: { color: 'var(--color-ink-2)', fontWeight: 600 },
  itemStyle: { color: 'var(--color-ink)' },
}
