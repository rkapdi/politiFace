import { describe, expect, it } from 'vitest'
import { toCsv } from './csv'

describe('toCsv', () => {
  it('renders headers from keys and escapes quotes, commas, newlines', () => {
    const csv = toCsv([
      { name: 'Alex "A" R', note: 'line1\nline2', score: 3 },
      { name: 'plain', note: 'a,b', score: null },
    ])
    expect(csv.split('\r\n')[0]).toBe('name,note,score')
    expect(csv).toContain('"Alex ""A"" R"')
    expect(csv).toContain('"line1\nline2"')
    expect(csv).toContain('"a,b"')
    expect(csv.endsWith('plain,"a,b",')).toBe(true)
  })

  it('returns an empty string for no rows', () => {
    expect(toCsv([])).toBe('')
  })
})
