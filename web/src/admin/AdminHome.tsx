import { useState } from 'react'
import { Link } from '@tanstack/react-router'
import { useDecideFacultyRequest, useFacultyRequests } from '../lib/api'
import { Badge } from '../components/ui'
import {
  isUnverifiedSignin,
  useAdminActivity,
  useAdminHome,
  useAdminOnline,
  useAdminPicture,
  type AdminHome as Home,
  type AdminPicture,
} from './adminApi'
import { buildDecisions, onTrackPct, type Decision } from './decisions'
import { Picture } from './Picture'
import { A } from './strings'

const time = (iso: string) =>
  new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })

const card = 'rounded-xl bg-panel p-5'
const cardTitle = 'text-[15px] font-bold text-ink'
const act =
  'inline-flex items-center rounded-full px-3 py-1.5 text-xs font-bold no-underline hover:no-underline disabled:cursor-not-allowed disabled:opacity-50'
const actPrimary = `${act} bg-cta text-on-cta hover:brightness-95`
const actGhost = `${act} bg-control text-ink hover:bg-line-strong`

type PictureState = { data: AdminPicture | undefined; isPending: boolean; error: Error | null }

function Proof({ label, n, of, accent = false }: { label: string; n: number; of: number; accent?: boolean }) {
  const p = of > 0 ? Math.round((n / of) * 100) : 0
  return (
    <div>
      <div className="flex justify-between text-[12.5px] font-semibold">
        <span className="text-ink-2">{label}</span>
        <span className="tabular-nums text-ink">{p}%</span>
      </div>
      <div className="mt-1.5 h-1 rounded-full bg-control" aria-hidden="true">
        <div
          className={`h-full rounded-full ${accent ? 'bg-accent-track' : 'bg-bar'}`}
          style={{ width: `${p}%` }}
        />
      </div>
    </div>
  )
}

/** The one number the product is bought for, and the three facts behind it. */
function Outcome({ home, picture }: { home: Home; picture: PictureState }) {
  const now = picture.data?.now
  const pct = now ? onTrackPct(now.on_track, now.students) : null
  // The snapshot from seven days back, when there is one.
  const then = picture.data?.days[picture.data.days.length - 8]
  const pctThen = then ? onTrackPct(then.on_track, then.students) : null
  const delta = pct != null && pctThen != null ? pct - pctThen : null
  return (
    <section className={card} aria-label={A.home.outcomeLabel}>
      <h2 className="admin-label">{A.home.outcomeLabel}</h2>
      {picture.isPending ? (
        <p className="mt-3 text-ink-3">{A.loading}</p>
      ) : !now ? (
        <p className="mt-3 text-ink-3" title={picture.error?.message}>
          {A.home.outcomeUnavailable}
        </p>
      ) : pct == null ? (
        <p className="mt-3 text-ink-2">{A.home.outcomeNoStudents}</p>
      ) : (
        <>
          <div className="mt-3 flex flex-wrap items-end gap-x-2.5 gap-y-2">
            <span className="text-[64px] font-extrabold leading-[58px] tracking-[-0.04em] text-ink tabular-nums">
              {pct}%
            </span>
            {delta != null ? (
              <span
                className={`mb-1 rounded-full px-2.5 py-0.5 text-xs font-bold ${
                  delta < 0
                    ? 'text-risk ring-[1.5px] ring-inset ring-risk-line'
                    : 'bg-accent text-on-accent'
                }`}
              >
                {A.home.delta(delta)}
              </span>
            ) : null}
          </div>
          <p className="mt-3 text-[13px] font-medium text-ink-2">
            {A.home.outcomeSentence(now.on_track, now.students)}
          </p>
          <div className="mt-4 flex flex-col gap-3 border-t border-line pt-4">
            <h3 className="text-xs font-bold text-ink-3">{A.home.howWeKnow}</h3>
            <Proof label={A.home.proofPractised} n={now.practised_7d} of={now.students} />
            <Proof label={A.home.proofLive} n={now.live_7d} of={now.students} />
            <Proof label={A.home.proofAbove} n={now.on_track} of={now.students} accent />
          </div>
        </>
      )}
      <p className="mt-4 border-t border-line pt-3 text-xs text-ink-3">
        {A.home.totals(home.totals.people, home.totals.classes, home.totals.faculty)}
      </p>
    </section>
  )
}

type ClassRow = {
  cohort_id: string
  name: string
  students: number
  practised_7d: number
  on_track: number | null
  is_demo: boolean
}

/** A class needs this many students before its share means anything. */
const FLOOR = 5

/** Weakest on-track share first; classes too small to judge, then demo classes, last. */
function classRows(home: Home, picture: AdminPicture | undefined): ClassRow[] {
  if (!picture) {
    return home.funnel.map(f => ({
      cohort_id: f.cohort_id,
      name: f.name,
      students: f.students,
      practised_7d: f.practiced_7d,
      on_track: null,
      is_demo: false,
    }))
  }
  const share = (c: ClassRow) => (c.students > 0 && c.on_track != null ? c.on_track / c.students : 2)
  const group = (c: ClassRow) => (c.is_demo ? 2 : c.students < FLOOR ? 1 : 0)
  return [...picture.classes].sort(
    (a, b) => group(a) - group(b) || share(a) - share(b) || a.name.localeCompare(b.name),
  )
}

function Classes({ home, picture }: { home: Home; picture: AdminPicture | undefined }) {
  const rows = classRows(home, picture)
  return (
    <section className={card} aria-label={A.home.classes}>
      <div className="flex items-center justify-between pb-2">
        <h2 className={cardTitle}>{A.home.classes}</h2>
        <span className="font-mono text-[11px] text-ink-3">{rows.length}</span>
      </div>
      {rows.length === 0 ? <p className="text-ink-3">{A.home.noClasses}</p> : null}
      <ul className="max-h-[440px] overflow-y-auto">
        {rows.map(c => {
          const pct = onTrackPct(c.on_track, c.students)
          const under = !c.is_demo && c.students >= FLOOR && c.on_track != null && c.on_track * 2 < c.students
          return (
            <li key={c.cohort_id} className="flex items-center gap-2.5 border-t border-line py-2.5">
              <div className="min-w-0 flex-1">
                <Link
                  to="/admin/classes/$cohortId"
                  params={{ cohortId: c.cohort_id }}
                  className="block truncate text-[13.5px] font-bold"
                >
                  {c.name}
                </Link>
                <div className="text-[11.5px] text-ink-3">
                  {A.home.classSub(c.students, c.practised_7d)}
                </div>
                {under || c.is_demo ? (
                  <div className="mt-1 flex gap-1.5">
                    {under ? <Badge tone="red">{A.home.underHalf}</Badge> : null}
                    {c.is_demo ? <Badge>{A.home.demo}</Badge> : null}
                  </div>
                ) : null}
              </div>
              {pct != null ? (
                <span
                  className={`w-12 shrink-0 text-right text-[15px] font-bold tabular-nums ${
                    under ? 'text-risk' : 'text-ink'
                  }`}
                >
                  {pct}%
                </span>
              ) : null}
            </li>
          )
        })}
      </ul>
    </section>
  )
}

function RightNow({ home }: { home: Home }) {
  const online = useAdminOnline()
  return (
    <section className={card} aria-label={A.home.rightNow}>
      <h2 className={cardTitle}>{A.home.liveNow}</h2>
      {home.live_now.length === 0 ? <p className="mt-1 text-ink-3">{A.home.noLiveSessions}</p> : null}
      <ul className="mt-2 flex flex-col gap-2">
        {home.live_now.map(s => (
          <li key={s.session_id} className="rounded-md bg-raised px-3 py-2">
            <Link to="/admin/sessions/$sessionId" params={{ sessionId: s.session_id }}>
              {s.title}
            </Link>{' '}
            · {s.class} · {s.index < 0 ? A.lobby : `Q${s.index + 1}/${s.total}`} · {s.participants}{' '}
            {A.home.inRoom}
            <div className="text-ink-3">
              {s.professor} · {A.home.startedAt} {time(s.created_at)}
            </div>
          </li>
        ))}
      </ul>
      <h2 className={`${cardTitle} mt-5`}>{A.home.onlineNow}</h2>
      {online.data && online.data.people.length === 0 ? (
        <p className="mt-1 text-ink-3">{A.home.nobodyOnline}</p>
      ) : null}
      <ul className="mt-1 max-h-48 overflow-y-auto">
        {(online.data?.people ?? []).map(p => (
          <li key={p.user_id} className="py-0.5">
            <Link to="/admin/people/$userId" params={{ userId: p.user_id }}>
              {p.name}
            </Link>{' '}
            <span className="text-ink-3">
              {p.clients
                .map(c =>
                  c === 'ios'
                    ? `${A.home.clientIos}${p.app_version ? ` ${p.app_version}` : ''}`
                    : A.home.clientWeb,
                )
                .join(' · ')}
            </span>
          </li>
        ))}
      </ul>
      {online.data && online.data.guests > 0 ? (
        <p className="mt-1 text-ink-3">{A.home.guestsOnline(online.data.guests)}</p>
      ) : null}
    </section>
  )
}

function ActivityStream() {
  const activity = useAdminActivity()
  return (
    <section className={card} aria-label={A.home.activity}>
      <h2 className={cardTitle}>{A.home.activity}</h2>
      <ol className="mt-2 max-h-80 overflow-y-auto">
        {(activity.data ?? []).map((r, i) => (
          <li key={`${r.at}-${i}`} className="border-t border-line py-1.5">
            <span className="font-mono text-[11px] text-ink-3">{time(r.at)}</span>{' '}
            <span className={`admin-label sev-${r.severity}`}>{r.kind.replace(/_/g, ' ')}</span>{' '}
            {r.user_id ? (
              <Link to="/admin/people/$userId" params={{ userId: r.user_id }}>
                {r.title}
              </Link>
            ) : (
              <span className="text-ink">{r.title}</span>
            )}
            {isUnverifiedSignin(r.kind, r.title) ? (
              <span className="text-ink-3"> {A.timeline.unverifiedEmail}</span>
            ) : null}
          </li>
        ))}
      </ol>
    </section>
  )
}

function DecisionCard({
  d,
  onDecide,
  busy,
}: {
  d: Decision
  onDecide: (id: string, approve: boolean) => void
  busy: boolean
}) {
  return (
    <li
      className={`rounded-lg bg-raised p-3.5 ${
        d.tone === 'risk' ? 'ring-[1.5px] ring-inset ring-risk-line' : ''
      }`}
    >
      <div className={`admin-label ${d.tone === 'risk' ? 'text-risk' : ''}`}>{d.tag}</div>
      <p className="mt-1.5 line-clamp-3 text-[13.5px] font-bold text-ink">{d.title}</p>
      {d.evidence.map(e => (
        <p key={e} className="mt-1 break-words text-[12.5px] leading-[18px] text-ink-2">
          {e}
        </p>
      ))}
      {d.request || d.cohortId || d.toInvites ? (
        <div className="mt-2.5 flex flex-wrap gap-2">
          {d.request ? (
            <>
              <button
                type="button"
                disabled={busy}
                className={actPrimary}
                onClick={() => onDecide(d.request!.id, true)}
              >
                {A.invites.approve}
              </button>
              <button
                type="button"
                disabled={busy}
                className={actGhost}
                onClick={() => onDecide(d.request!.id, false)}
              >
                {A.invites.deny}
              </button>
            </>
          ) : null}
          {d.cohortId ? (
            <Link to="/admin/classes/$cohortId" params={{ cohortId: d.cohortId }} className={actGhost}>
              {A.home.openClass}
            </Link>
          ) : null}
          {d.toInvites ? (
            <Link to="/admin/invites" className={actGhost}>
              {A.home.reviewRequests}
            </Link>
          ) : null}
        </div>
      ) : null}
    </li>
  )
}

function Decisions({ home, picture }: { home: Home; picture: AdminPicture | undefined }) {
  const requests = useFacultyRequests(true)
  const decide = useDecideFacultyRequest()
  // Day counts only need the time this screen opened.
  const [openedAt] = useState(() => Date.now())
  const list = buildDecisions(home, picture, requests.data, openedAt)
  return (
    <section className={card} aria-label={A.home.decisions}>
      <div className="flex items-center justify-between">
        <h2 className={cardTitle}>{A.home.decisions}</h2>
        <span className="font-mono text-[11px] uppercase text-ink-3">
          {A.home.openCount(list.length)}
        </span>
      </div>
      <p className="text-xs text-ink-3">{A.home.decisionsSub}</p>
      {decide.error ? <p className="sev-fail mt-2">{decide.error.message}</p> : null}
      {list.length === 0 ? <p className="mt-3 text-ink-2">{A.home.nothingToDecide}</p> : null}
      <ul className="mt-3 flex flex-col gap-2.5">
        {list.map(d => (
          <DecisionCard
            key={d.key}
            d={d}
            busy={decide.isPending}
            onDecide={(id, approve) => decide.mutate({ id, approve })}
          />
        ))}
      </ul>
    </section>
  )
}

export function AdminHome() {
  const home = useAdminHome()
  const picture = useAdminPicture()
  if (home.isPending) return <p>{A.loading}</p>
  if (home.error || !home.data) return <p className="sev-fail">{home.error?.message}</p>
  const h = home.data
  return (
    <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-[300px_minmax(0,1fr)_340px] xl:items-start">
      <h1 className="sr-only">{A.titles.home}</h1>
      <div className="flex flex-col gap-3">
        <Outcome home={h} picture={picture} />
        <Classes home={h} picture={picture.data} />
      </div>
      <div className="order-last flex min-w-0 flex-col gap-3 md:col-span-2 xl:order-none xl:col-span-1">
        <section className={card} aria-label={A.home.picture}>
          <div className="pb-3">
            <h2 className={cardTitle}>{A.home.picture}</h2>
            <p className="text-xs text-ink-3">{A.home.pictureSub}</p>
          </div>
          {picture.data ? (
            <Picture picture={picture.data} />
          ) : (
            <p className="text-ink-3" title={picture.error?.message}>
              {picture.isPending ? A.loading : A.home.pictureUnavailable}
            </p>
          )}
        </section>
        <div className="grid gap-3 lg:grid-cols-2">
          <RightNow home={h} />
          <ActivityStream />
        </div>
      </div>
      <Decisions home={h} picture={picture.data} />
    </div>
  )
}
