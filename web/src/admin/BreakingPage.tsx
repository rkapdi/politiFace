import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { Check, Circle, TriangleAlert } from 'lucide-react'
import { BrandMark } from '../components/Brand'
import { Alert, Badge, Button, fieldClass } from '../components/ui'
import {
  DETAIL_MAX,
  FIELD_ORDER,
  HEADLINE_MAX,
  KINDS,
  NOTE_MAX,
  NOT_DEPLOYED,
  chars,
  emptyDraft,
  explain,
  sourceHost,
  validate,
  type Draft,
  type Field,
  type FieldErrors,
} from './breaking'
import {
  useBreakingList,
  usePublishBreaking,
  useRetractBreaking,
  type BreakingItem,
  type BreakingPublished,
} from './breakingApi'
import { A } from './strings'

const B = A.breaking

const card = 'rounded-xl bg-panel p-5'
const cardTitle = 'text-[15px] font-bold text-ink'
const label = 'text-[13px] font-bold text-ink'
const hint = 'mt-0.5 text-xs text-ink-3'
const radio = 'size-4 shrink-0 accent-[var(--color-accent)]'
// A choice is a whole clickable row. The chosen one has a ring as well as
// the filled radio, so the state never rests on colour.
const choice =
  'flex cursor-pointer items-center gap-2 bg-control text-ink-2 has-[:checked]:bg-raised has-[:checked]:text-ink has-[:checked]:ring-[1.5px] has-[:checked]:ring-inset has-[:checked]:ring-ink has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus'

/** The element to focus for each field when it has a problem. */
const focusId: Record<Field, string> = {
  kind: `bk-kind-${KINDS[0]}`,
  headline: 'bk-headline',
  detail: 'bk-detail',
  source: 'bk-source',
  second: 'bk-second',
  delivery: 'bk-delivery-notify',
}

const when = (iso: string) =>
  new Date(iso).toLocaleString([], {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })

function FieldError({ id, text }: { id: string; text: string | undefined }) {
  if (!text) return null
  return (
    <p id={id} className="mt-1.5 flex items-start gap-1.5 text-xs font-bold text-risk">
      <TriangleAlert aria-hidden="true" className="mt-px size-3.5 shrink-0" />
      {text}
    </p>
  )
}

function Count({ used, max }: { used: number; max: number }) {
  return (
    <span
      className={`font-mono text-[11px] tabular-nums ${
        used > max ? 'font-bold text-risk underline' : 'text-ink-3'
      }`}
    >
      {B.count(used, max)}
    </span>
  )
}

/** The notification as a phone shows it: the title, then the headline. */
function NotificationMock({ headline }: { headline: string }) {
  const text = headline.trim()
  return (
    <div className="flex gap-3 rounded-2xl bg-raised p-3.5">
      <BrandMark size={36} />
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2">
          <span className="text-[13px] font-bold text-ink">{B.notificationTitle}</span>
          <span className="text-[11px] text-ink-3">{B.notificationNow}</span>
        </div>
        <p className={`break-words text-[13px] leading-[18px] ${text ? 'text-ink' : 'text-ink-3'}`}>
          {text || B.headlinePlaceholder}
        </p>
      </div>
    </div>
  )
}

/** The item's own screen in the app: marked as reported, with its source. */
function AppMock({ draft }: { draft: Draft }) {
  const headline = draft.headline.trim()
  const detail = draft.detail.trim()
  const source = draft.source.trim()
  return (
    <div className="rounded-2xl bg-raised p-3.5">
      {draft.kind ? <div className="admin-label">{B.kinds[draft.kind]}</div> : null}
      <p
        className={`mt-1 break-words text-[14px] font-bold leading-5 ${
          headline ? 'text-ink' : 'text-ink-3'
        }`}
      >
        {headline || B.headlinePlaceholder}
      </p>
      {detail ? (
        <p className="mt-1.5 break-words text-[12.5px] leading-[18px] text-ink-2">{detail}</p>
      ) : null}
      <p className="mt-2 text-[11.5px] font-semibold text-ink-3">
        {B.reported} · {source ? sourceHost(source) : B.sourcePlaceholder}
      </p>
    </div>
  )
}

function Preview({ draft }: { draft: Draft }) {
  return (
    <section className={`${card} xl:sticky xl:top-3`} aria-label={B.previewTitle}>
      <h2 className={cardTitle}>{B.previewTitle}</h2>
      <h3 className="admin-label mt-4">{B.previewNotification}</h3>
      {draft.notify === false ? (
        <p className="mt-2 text-[13px] text-ink-2">{B.previewNoNotification}</p>
      ) : (
        <>
          <div className="mt-2">
            <NotificationMock headline={draft.headline} />
          </div>
          {draft.notify == null ? <p className={`${hint} mt-2`}>{B.previewUndecided}</p> : null}
        </>
      )}
      <h3 className="admin-label mt-5">{B.previewApp}</h3>
      <div className="mt-2">
        <AppMock draft={draft} />
      </div>
    </section>
  )
}

function SourceLinks({
  first,
  official,
  second,
}: {
  first: string
  official: boolean
  second: string | null
}) {
  const link = (url: string): ReactNode =>
    url.startsWith('https://') ? (
      <a href={url} target="_blank" rel="noopener noreferrer">
        {sourceHost(url)}
      </a>
    ) : (
      sourceHost(url)
    )
  return (
    <>
      {link(first)}
      {official ? <span className="text-ink-3"> ({B.officialTag})</span> : null}
      {second ? <>, {link(second)}</> : null}
    </>
  )
}

/** The last step before anything is sent: what goes out, and to whom. */
function Confirm({
  draft,
  busy,
  onBack,
  onPublish,
}: {
  draft: Draft
  busy: boolean
  onBack: () => void
  onPublish: () => void
}) {
  const notify = draft.notify === true
  return (
    <div
      role="group"
      aria-label={B.confirmGroup}
      className={`mt-5 rounded-lg bg-raised p-4 ${
        notify ? 'ring-[1.5px] ring-inset ring-risk-line' : ''
      }`}
    >
      <h3 className="flex items-center gap-2 text-[15px] font-bold text-ink">
        {notify ? <TriangleAlert aria-hidden="true" className="size-4 shrink-0 text-risk" /> : null}
        {notify ? B.confirmNotifyTitle : B.confirmFeedTitle}
      </h3>
      <p className="mt-1 text-[13px] leading-5 text-ink-2">
        {notify ? B.confirmNotifyBody : B.confirmFeedBody}
      </p>
      <div className="mt-3 rounded-2xl bg-panel p-1">
        {notify ? <NotificationMock headline={draft.headline} /> : <AppMock draft={draft} />}
      </div>
      <dl className="mt-3 grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-1 text-[12.5px]">
        <dt className="text-ink-3">{B.summaryKind}</dt>
        <dd className="text-ink">{draft.kind ? B.kinds[draft.kind] : ''}</dd>
        <dt className="text-ink-3">{B.summarySources}</dt>
        <dd className="break-words text-ink">
          <SourceLinks
            first={draft.source.trim()}
            official={draft.official}
            second={draft.second.trim() || null}
          />
        </dd>
      </dl>
      <div className="mt-4 flex flex-wrap gap-2">
        <Button id="bk-back" type="button" variant="ghost" disabled={busy} onClick={onBack}>
          {B.backToEdit}
        </Button>
        <Button type="button" disabled={busy} onClick={onPublish}>
          {busy ? B.publishing : notify ? B.publishNotify : B.publishFeed}
        </Button>
      </div>
    </div>
  )
}

function doneText(r: BreakingPublished): string {
  if (r.duplicate) return B.doneDuplicate
  if (!r.notify) return B.doneFeed
  return r.kicked ? B.doneKicked : B.doneQueued
}

/** The form and, beside it, what it will put on phones. */
function Composer({ disabled }: { disabled: boolean }) {
  const publish = usePublishBreaking()
  const [draft, setDraft] = useState<Draft>(emptyDraft)
  const [errors, setErrors] = useState<FieldErrors>({})
  const [formError, setFormError] = useState<string | null>(null)
  const [reviewing, setReviewing] = useState(false)
  const [result, setResult] = useState<BreakingPublished | null>(null)
  // Where focus goes once the next render has put the element on screen.
  const focusNext = useRef<string | null>(null)
  useEffect(() => {
    if (!focusNext.current) return
    document.getElementById(focusNext.current)?.focus()
    focusNext.current = null
  })

  const set = (patch: Partial<Draft>) => {
    setDraft(d => ({ ...d, ...patch }))
    setResult(null)
    setFormError(null)
    // A field's message goes once that field is edited; the rest stay.
    const cleared: Field[] = []
    if ('kind' in patch) cleared.push('kind')
    if ('headline' in patch) cleared.push('headline')
    if ('detail' in patch) cleared.push('detail')
    if ('source' in patch) cleared.push('source', 'second')
    if ('second' in patch || 'official' in patch) cleared.push('second')
    if ('notify' in patch) cleared.push('delivery')
    setErrors(e => {
      const next = { ...e }
      for (const f of cleared) delete next[f]
      return next
    })
  }

  const showErrors = (found: FieldErrors) => {
    setErrors(found)
    const first = FIELD_ORDER.find(f => found[f])
    if (first) focusNext.current = focusId[first]
  }

  const review = (e: FormEvent) => {
    e.preventDefault()
    const found = validate(draft)
    setFormError(null)
    setResult(null)
    if (Object.keys(found).length > 0) return showErrors(found)
    setErrors({})
    setReviewing(true)
    focusNext.current = 'bk-back'
  }

  const back = () => {
    setReviewing(false)
    focusNext.current = 'bk-review'
  }

  const send = () => {
    if (draft.kind == null || draft.notify == null) return
    publish.mutate(
      { ...draft, kind: draft.kind, notify: draft.notify },
      {
        onSuccess: r => {
          setResult(r)
          setDraft(emptyDraft)
          setErrors({})
          setReviewing(false)
          focusNext.current = 'bk-result'
        },
        onError: err => {
          const x = explain(err.message, draft)
          setReviewing(false)
          if (x.field) showErrors({ [x.field]: x.text })
          else {
            setFormError(x.text)
            focusNext.current = 'bk-review'
          }
        },
      },
    )
  }

  const locked = disabled || reviewing || publish.isPending
  const live = validate(draft)
  const ruleMet = !live.source && !live.second
  const problems = Object.keys(errors).length
  const described = (id: string, f: Field) => (errors[f] ? `${id}-hint ${id}-err` : `${id}-hint`)

  return (
    <>
      <form onSubmit={review} noValidate aria-label={B.formTitle} className={card}>
        <h2 className={cardTitle}>{B.formTitle}</h2>
        {result ? (
          <div id="bk-result" tabIndex={-1} className="mt-3 outline-none">
            <Alert tone={result.duplicate ? 'info' : 'success'}>{doneText(result)}</Alert>
          </div>
        ) : null}
        <fieldset
          disabled={locked}
          className="mt-4 flex min-w-0 flex-col gap-6 disabled:opacity-60"
        >
          <fieldset aria-describedby={errors.kind ? 'bk-kind-err' : undefined}>
            <legend className={label}>{B.kindLegend}</legend>
            <div className="mt-2 flex flex-wrap gap-2">
              {KINDS.map(k => (
                <label
                  key={k}
                  className={`${choice} rounded-full px-3.5 py-2 text-[13px] font-semibold`}
                >
                  <input
                    type="radio"
                    name="bk-kind"
                    id={`bk-kind-${k}`}
                    className={radio}
                    checked={draft.kind === k}
                    onChange={() => set({ kind: k })}
                  />
                  {B.kinds[k]}
                </label>
              ))}
            </div>
            <FieldError id="bk-kind-err" text={errors.kind} />
          </fieldset>

          <div>
            <div className="flex items-baseline justify-between gap-3">
              <label htmlFor="bk-headline" className={label}>
                {B.headlineLabel}
              </label>
              <Count used={chars(draft.headline.trim())} max={HEADLINE_MAX} />
            </div>
            <p id="bk-headline-hint" className={hint}>
              {B.headlineHint}
            </p>
            <textarea
              id="bk-headline"
              rows={2}
              value={draft.headline}
              onChange={e => set({ headline: e.target.value })}
              aria-invalid={errors.headline ? true : undefined}
              aria-describedby={described('bk-headline', 'headline')}
              className={`${fieldClass} mt-2 w-full resize-y`}
            />
            <FieldError id="bk-headline-err" text={errors.headline} />
          </div>

          <div>
            <div className="flex items-baseline justify-between gap-3">
              <label htmlFor="bk-detail" className={label}>
                {B.detailLabel}
              </label>
              <Count used={chars(draft.detail.trim())} max={DETAIL_MAX} />
            </div>
            <p id="bk-detail-hint" className={hint}>
              {B.detailHint}
            </p>
            <textarea
              id="bk-detail"
              rows={3}
              value={draft.detail}
              onChange={e => set({ detail: e.target.value })}
              aria-invalid={errors.detail ? true : undefined}
              aria-describedby={described('bk-detail', 'detail')}
              className={`${fieldClass} mt-2 w-full resize-y`}
            />
            <FieldError id="bk-detail-err" text={errors.detail} />
          </div>

          <fieldset className="rounded-lg bg-raised p-4">
            <legend className={`${label} float-left w-full`}>{B.sourcesLegend}</legend>
            <div className="clear-both flex flex-wrap items-center justify-between gap-x-4 gap-y-1 pt-0.5">
              <p id="bk-source-hint" className="text-[13px] font-semibold text-ink-2">
                {B.sourcesRule}
              </p>
              <p
                aria-live="polite"
                className={`flex items-center gap-1.5 text-xs font-bold ${
                  ruleMet ? 'text-ink' : 'text-ink-3'
                }`}
              >
                {ruleMet ? (
                  <Check aria-hidden="true" className="size-3.5 shrink-0" />
                ) : (
                  <Circle aria-hidden="true" className="size-3.5 shrink-0" />
                )}
                {ruleMet ? B.ruleMet : B.ruleNotMet}
              </p>
            </div>
            <div className="mt-4">
              <label htmlFor="bk-source" className={label}>
                {B.sourceLabel}
              </label>
              <input
                id="bk-source"
                type="url"
                inputMode="url"
                autoComplete="off"
                placeholder={B.linkPlaceholder}
                value={draft.source}
                onChange={e => set({ source: e.target.value })}
                aria-invalid={errors.source ? true : undefined}
                aria-describedby={described('bk-source', 'source')}
                className={`${fieldClass} mt-2 w-full`}
              />
              <FieldError id="bk-source-err" text={errors.source} />
            </div>
            <label className="mt-4 flex cursor-pointer items-start gap-2.5">
              <input
                type="checkbox"
                className={`${radio} mt-0.5`}
                checked={draft.official}
                onChange={e => set({ official: e.target.checked })}
                aria-describedby="bk-official-hint"
              />
              <span>
                <span className="text-[13px] font-bold text-ink">{B.officialLabel}</span>
                <span id="bk-official-hint" className={`${hint} block`}>
                  {B.officialHint}
                </span>
              </span>
            </label>
            <div className="mt-4">
              <label htmlFor="bk-second" className={label}>
                {draft.official ? B.secondOptional : B.secondRequired}
              </label>
              <input
                id="bk-second"
                type="url"
                inputMode="url"
                autoComplete="off"
                placeholder={B.linkPlaceholder}
                value={draft.second}
                onChange={e => set({ second: e.target.value })}
                aria-invalid={errors.second ? true : undefined}
                aria-describedby={described('bk-second', 'second').replace(
                  'bk-second-hint',
                  'bk-source-hint',
                )}
                className={`${fieldClass} mt-2 w-full`}
              />
              <FieldError id="bk-second-err" text={errors.second} />
            </div>
          </fieldset>

          <fieldset aria-describedby={errors.delivery ? 'bk-delivery-err' : undefined}>
            <legend className={label}>{B.deliveryLegend}</legend>
            <div className="mt-2 grid gap-2.5 sm:grid-cols-2">
              {(
                [
                  {
                    id: 'notify',
                    value: true,
                    title: B.notifyLabel,
                    text: B.notifyHint,
                  },
                  {
                    id: 'feed',
                    value: false,
                    title: B.feedLabel,
                    text: B.feedHint,
                  },
                ] as const
              ).map(o => (
                <label key={o.id} className={`${choice} items-start rounded-lg p-3.5`}>
                  <input
                    type="radio"
                    name="bk-delivery"
                    id={`bk-delivery-${o.id}`}
                    className={`${radio} mt-0.5`}
                    checked={draft.notify === o.value}
                    onChange={() => set({ notify: o.value })}
                    aria-describedby={`bk-delivery-${o.id}-hint`}
                  />
                  <span>
                    <span className="block text-[13.5px] font-bold text-ink">{o.title}</span>
                    <span
                      id={`bk-delivery-${o.id}-hint`}
                      className="mt-0.5 block text-xs leading-[17px] text-ink-2"
                    >
                      {o.text}
                    </span>
                  </span>
                </label>
              ))}
            </div>
            <FieldError id="bk-delivery-err" text={errors.delivery} />
          </fieldset>
        </fieldset>

        {formError ? (
          <div className="mt-4">
            <Alert>{formError}</Alert>
          </div>
        ) : null}

        {reviewing ? (
          <Confirm draft={draft} busy={publish.isPending} onBack={back} onPublish={send} />
        ) : (
          <div className="mt-5 flex flex-wrap items-center gap-3">
            <Button id="bk-review" type="submit" disabled={disabled}>
              {B.review}
            </Button>
            {problems > 0 ? (
              <span className="text-xs font-bold text-risk">{B.fixFirst(problems)}</span>
            ) : null}
          </div>
        )}
      </form>
      <Preview draft={draft} />
    </>
  )
}

function Item({ item }: { item: BreakingItem }) {
  const retract = useRetractBreaking()
  const [open, setOpen] = useState(false)
  const [note, setNote] = useState('')
  const [error, setError] = useState<string | null>(null)
  const focusNext = useRef<string | null>(null)
  useEffect(() => {
    if (!focusNext.current) return
    document.getElementById(focusNext.current)?.focus()
    focusNext.current = null
  })
  const gone = item.retracted_at != null
  const noteId = `bk-note-${item.id}`
  const openId = `bk-retract-${item.id}`

  const close = () => {
    setOpen(false)
    setError(null)
    focusNext.current = openId
  }
  const send = () => {
    if (chars(note.trim()) > NOTE_MAX) return setError(B.errNote)
    setError(null)
    retract.mutate(
      { id: item.id, note },
      {
        onSuccess: () => setOpen(false),
        onError: err => setError(explain(err.message).text),
      },
    )
  }

  return (
    <li className="border-t border-line py-4">
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1.5">
        <Badge>{B.kinds[item.kind] ?? item.kind}</Badge>
        {gone ? <Badge tone="red">{B.retracted}</Badge> : null}
        <span className="text-[11.5px] text-ink-3">
          {when(item.published_at)} · {B.by(item.published_by)} ·{' '}
          {item.notify ? B.notified : B.feedOnly}
        </span>
      </div>
      <p
        className={`mt-2 break-words text-[14px] font-bold leading-5 ${
          gone ? 'text-ink-3 line-through' : 'text-ink'
        }`}
      >
        {item.headline}
      </p>
      {item.detail ? (
        <p className="mt-1 break-words text-[12.5px] leading-[18px] text-ink-2">{item.detail}</p>
      ) : null}
      <p className="mt-1.5 break-words text-[12.5px] text-ink-2">
        <span className="text-ink-3">{B.summarySources}: </span>
        <SourceLinks
          first={item.source_url}
          official={item.source_is_official}
          second={item.second_source_url}
        />
      </p>
      {gone ? (
        <p className="mt-1.5 break-words text-[12.5px] text-ink-2">
          {B.retractedAt(when(item.retracted_at!))}
          {item.retraction_note ? `. ${item.retraction_note}` : ''}
        </p>
      ) : open ? (
        <div
          role="group"
          aria-label={B.retractGroup}
          className="mt-3 rounded-lg bg-raised p-4 ring-[1.5px] ring-inset ring-risk-line"
        >
          <h3 className="text-[14px] font-bold text-ink">{B.retractTitle}</h3>
          <p id={`${noteId}-warn`} className="mt-1 text-[13px] leading-5 text-ink-2">
            {B.retractBody}
          </p>
          <div className="mt-3 flex items-baseline justify-between gap-3">
            <label htmlFor={noteId} className={label}>
              {B.noteLabel}
            </label>
            <Count used={chars(note.trim())} max={NOTE_MAX} />
          </div>
          <input
            id={noteId}
            value={note}
            onChange={e => setNote(e.target.value)}
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? `${noteId}-warn ${noteId}-err` : `${noteId}-warn`}
            className={`${fieldClass} mt-2 w-full`}
          />
          <FieldError id={`${noteId}-err`} text={error ?? undefined} />
          <div className="mt-3 flex flex-wrap gap-2">
            <Button type="button" variant="ghost" disabled={retract.isPending} onClick={close}>
              {B.cancel}
            </Button>
            <Button type="button" variant="danger" disabled={retract.isPending} onClick={send}>
              {retract.isPending ? B.retracting : B.retractConfirm}
            </Button>
          </div>
        </div>
      ) : (
        <Button
          id={openId}
          type="button"
          variant="ghost"
          className="mt-2.5 !px-3 !py-1.5 !text-xs"
          onClick={() => {
            setOpen(true)
            focusNext.current = noteId
          }}
        >
          {B.retract}
        </Button>
      )}
    </li>
  )
}

/** Publish, retract and review what no official record carries yet. */
export function BreakingPage() {
  const list = useBreakingList()
  const notDeployed = list.error?.message === NOT_DEPLOYED
  return (
    <div className="flex flex-col gap-3">
      <header className="px-1 pt-1">
        <h1 className="text-[22px] font-extrabold tracking-[-0.02em] text-ink">
          {A.titles.breaking}
        </h1>
        <p className="mt-0.5 max-w-[62ch] text-[13px] text-ink-2">{B.intro}</p>
      </header>
      {notDeployed ? <Alert tone="info">{B.notDeployed}</Alert> : null}
      <div className="grid gap-3 xl:grid-cols-[minmax(0,1fr)_360px] xl:items-start">
        <Composer disabled={notDeployed} />
      </div>
      <section className={card} aria-label={B.listTitle}>
        <div className="flex items-center justify-between pb-2">
          <h2 className={cardTitle}>{B.listTitle}</h2>
          {list.data ? (
            <span className="font-mono text-[11px] text-ink-3">{list.data.length}</span>
          ) : null}
        </div>
        {list.isPending ? <p className="text-ink-3">{A.loading}</p> : null}
        {list.error && !notDeployed ? <Alert>{explain(list.error.message).text}</Alert> : null}
        {list.data?.length === 0 ? <p className="text-ink-3">{B.listEmpty}</p> : null}
        <ul>
          {(list.data ?? []).map(item => (
            <Item key={item.id} item={item} />
          ))}
        </ul>
      </section>
    </div>
  )
}
