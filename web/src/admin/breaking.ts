// The breaking desk's rules, mirrored from the server so the form can show
// them before anything is sent. The server (admin_publish_breaking) stays
// the authority: every rule here is enforced there too.
import { friendlyMessage } from '../lib/api'
import { A } from './strings'

export const KINDS = ['removed', 'resigned', 'appointed', 'died', 'other'] as const
export type BreakingKind = (typeof KINDS)[number]

export type Field = 'kind' | 'headline' | 'detail' | 'source' | 'second' | 'delivery'
export type FieldErrors = Partial<Record<Field, string>>

/** The form as typed. Kind and delivery start unset: the editor must choose. */
export type Draft = {
  kind: BreakingKind | null
  headline: string
  detail: string
  source: string
  official: boolean
  second: string
  /** true notifies every phone, false adds to the feed only. */
  notify: boolean | null
}
export const emptyDraft: Draft = {
  kind: null,
  headline: '',
  detail: '',
  source: '',
  official: false,
  second: '',
  notify: null,
}

export const HEADLINE_MIN = 12
export const HEADLINE_MAX = 160
export const DETAIL_MAX = 600
export const NOTE_MAX = 300
const LINK_MAX = 500

const HTTPS = /^https:\/\/\S+$/
const LONG_DASH = /[–—]/

/** Characters as the database counts them, not UTF-16 units. */
export const chars = (s: string) => [...s].length

const isLink = (s: string) => HTTPS.test(s) && chars(s) <= LINK_MAX

/** Every rule the server checks, plus the two choices the form insists on. */
export function validate(d: Draft): FieldErrors {
  const e: FieldErrors = {}
  const headline = d.headline.trim()
  const detail = d.detail.trim()
  const source = d.source.trim()
  const second = d.second.trim()

  if (d.kind == null) e.kind = A.breaking.errKind
  if (chars(headline) < HEADLINE_MIN || chars(headline) > HEADLINE_MAX) {
    e.headline = A.breaking.errHeadline
  } else if (LONG_DASH.test(headline)) {
    e.headline = A.breaking.errDash
  }
  if (chars(detail) > DETAIL_MAX) e.detail = A.breaking.errDetail
  else if (LONG_DASH.test(detail)) e.detail = A.breaking.errDash
  if (!isLink(source)) e.source = A.breaking.errSource
  if (second !== '' && !isLink(second)) e.second = A.breaking.errSecond
  else if (!d.official && (second === '' || second === source)) e.second = A.breaking.errTwoSources
  if (d.notify == null) e.delivery = A.breaking.errDelivery
  return e
}

/** The order the fields appear in, for moving focus to the first problem. */
export const FIELD_ORDER: Field[] = ['kind', 'headline', 'detail', 'source', 'second', 'delivery']

/** Set by the API layer when the server functions do not exist yet. */
export const NOT_DEPLOYED = 'breaking desk not deployed'

/**
 * A server refusal in the console's words, and the field it belongs to
 * when it has one. The server's messages are its contract (see the
 * breaking desk migration); anything else falls back to the shared copy.
 */
export function explain(message: string, d?: Draft): { field?: Field; text: string } {
  switch (message) {
    case 'unknown kind':
      return { field: 'kind', text: A.breaking.errKind }
    case 'the headline must be 12 to 160 characters':
      return { field: 'headline', text: A.breaking.errHeadline }
    case 'use a comma or a full stop instead of a dash':
      return {
        field: d && !LONG_DASH.test(d.headline) && LONG_DASH.test(d.detail) ? 'detail' : 'headline',
        text: A.breaking.errDash,
      }
    case 'the detail must be 600 characters or fewer':
      return { field: 'detail', text: A.breaking.errDetail }
    case 'the source must be an https link':
      return { field: 'source', text: A.breaking.errSource }
    case 'the second source must be an https link':
      return { field: 'second', text: A.breaking.errSecond }
    case 'a second, different source is required unless the first is an official statement':
      return { field: 'second', text: A.breaking.errTwoSources }
    case 'the note must be 300 characters or fewer':
      return { text: A.breaking.errNote }
    case 'no such item':
      return { text: A.breaking.errNoItem }
    case 'admin only':
      return { text: A.breaking.errAdminOnly }
    case NOT_DEPLOYED:
      return { text: A.breaking.notDeployed }
    default:
      return { text: friendlyMessage({ message }) }
  }
}

/** The site a link points at, for showing a source without its full address. */
export function sourceHost(url: string): string {
  try {
    return new URL(url).host.replace(/^www\./, '')
  } catch {
    return url
  }
}
