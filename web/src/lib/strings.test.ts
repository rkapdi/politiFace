import { describe, expect, it } from 'vitest'
import { S } from './strings'

// House voice: professional, direct, no em-dashes (Politiface standing
// rule), no gamified filler on the educator side.
const BANNED = ['—', 'oops', 'whoops', 'yay', 'awesome', 'uh oh', '🎉']

function collect(node: unknown, path: string, out: [string, string][]) {
  if (typeof node === 'string') {
    out.push([path, node])
    return
  }
  if (node && typeof node === 'object') {
    for (const [k, v] of Object.entries(node)) collect(v, `${path}.${k}`, out)
  }
}

describe('UI strings', () => {
  const all: [string, string][] = []
  collect(S, 'S', all)

  it('has strings to audit', () => {
    expect(all.length).toBeGreaterThan(20)
  })

  it('every string is non-empty and on-voice', () => {
    for (const [path, s] of all) {
      expect(s.trim().length, path).toBeGreaterThan(0)
      for (const banned of BANNED) {
        expect(s.toLowerCase().includes(banned.toLowerCase()), `${path} contains "${banned}"`).toBe(
          false,
        )
      }
    }
  })
})
