import { useState } from 'react'
import { useNavigate, useParams, useSearch } from '@tanstack/react-router'
import {
  useCohortDistribution,
  useCohortOverview,
  useCohortPulse,
  useCohortRole,
  useDomains,
  useDomainStats,
  useEngagementTrend,
  useLogExport,
  useReportingPolicy,
  useTopMisses,
  type CohortPulse,
  type PulseCardData,
} from '../lib/api'
import { supabase } from '../lib/supabase'
import { SUPABASE_URL } from '../lib/config'
import { S } from '../lib/strings'
import {
  Alert,
  Button,
  Card,
  Spinner,
  Stat,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '../components/ui'
import { PolicyBanner } from '../components/PolicyBanner'
import { ClassHeader } from '../components/ClassHeader'
import { SkeletonChart, SkeletonStats } from '../components/Skeleton'
import { DomainBars } from '../components/DomainBars'
import { TrendChart } from '../components/TrendChart'
import { TopMisses } from '../components/TopMisses'
import { StudentsTab } from '../components/StudentsTab'
import { SettingsTab } from '../components/SettingsTab'
import { LiveTab, emptyLiveDraft } from '../components/LiveTab'
import { PulseBanner } from '../components/PulseBanner'
import { DistributionChart } from '../components/DistributionChart'
import { MessageClassDialog } from '../components/MessageClassDialog'

const CLASS_TABS = ['overview', 'students', 'live', 'settings'] as const
export type ClassTab = (typeof CLASS_TABS)[number]

export const parseClassTab = (value: unknown): ClassTab | undefined =>
  CLASS_TABS.find(t => t === value)

// The open tab lives in the URL, so Back from a student or a session returns
// to where the instructor was, and a tab can be linked or reloaded.
export function ClassPage() {
  const { cohortId } = useParams({ strict: false }) as { cohortId: string }
  const { tab } = useSearch({ strict: false }) as { tab?: ClassTab }
  const navigate = useNavigate()
  return (
    <ClassView
      cohortId={cohortId}
      tab={tab ?? 'overview'}
      onTabChange={next =>
        void navigate({
          to: '/class/$cohortId',
          params: { cohortId },
          search: next === 'overview' ? {} : { tab: next },
          replace: true,
        })
      }
    />
  )
}

export function PassRateCard({ pulse }: { pulse: CohortPulse | undefined }) {
  const known = pulse && !pulse.below_floor && pulse.above_line !== undefined && pulse.students > 0
  const pct = known ? Math.round((pulse.above_line! / pulse.students) * 100) : null
  return (
    <div className="flex min-h-[216px] flex-col justify-between gap-4 rounded-xl bg-accent p-5 text-on-accent">
      <span className="text-[13px] font-bold text-on-accent-2">{S.pulse.passRate}</span>
      <div className="flex items-end gap-0.5">
        <b className="text-[92px] font-extrabold leading-[0.9] tracking-[-0.05em] tabular-nums">
          {pct ?? 'n/a'}
        </b>
        {pct !== null ? (
          <span className="text-4xl font-bold leading-[44px] text-on-accent-2">%</span>
        ) : null}
      </div>
      <div className="flex flex-col gap-2">
        <div aria-hidden="true" className="h-2 rounded-full bg-accent-track">
          <div className="h-2 rounded-full bg-on-accent" style={{ width: `${pct ?? 0}%` }} />
        </div>
        <p className="text-[13px] font-semibold">
          {known ? S.pulse.passNote(pulse.above_line!, pulse.students) : S.pulse.passFloor}
        </p>
      </div>
    </div>
  )
}

function OverviewTab({
  cohortId,
  pulse,
  onPulseAction,
}: {
  cohortId: string
  pulse: CohortPulse | undefined
  onPulseAction: (card: PulseCardData) => void
}) {
  const overview = useCohortOverview(cohortId)
  const domains = useDomainStats(cohortId)
  const misses = useTopMisses(cohortId)
  const trend = useEngagementTrend(cohortId)
  const distribution = useCohortDistribution(cohortId)
  const logExport = useLogExport()
  const [onePagerError, setOnePagerError] = useState<string | null>(null)

  if (overview.isPending) {
    return (
      <div className="flex flex-col gap-3">
        <SkeletonStats />
        <SkeletonChart />
      </div>
    )
  }
  if (overview.error) return <Alert tone="error">{overview.error.message}</Alert>

  const o = overview.data
  const belowFloor = o !== undefined && o.active_7d === null
  const showDistribution = distribution.data !== undefined && !distribution.data.below_floor

  const openOnePager = async () => {
    setOnePagerError(null)
    // Open the tab inside the click itself: a window opened after an await
    // is treated as a popup and blocked.
    const w = window.open('', '_blank')
    if (!w) {
      setOnePagerError(S.onePager.blocked)
      return
    }
    w.document.title = S.onePager.preparing
    w.document.body.textContent = S.onePager.preparing
    const fail = (message: string) => {
      w.close()
      setOnePagerError(message)
    }
    try {
      const { data } = await supabase.auth.getSession()
      const token = data.session?.access_token
      if (!token) return fail(S.onePager.failed)
      const res = await fetch(
        `${SUPABASE_URL}/functions/v1/efficacy-report?cohort_id=${encodeURIComponent(cohortId)}`,
        { headers: { Authorization: `Bearer ${token}` } },
      )
      if (res.status === 404) return fail(S.onePager.noData)
      if (!res.ok) return fail(S.onePager.failed)
      const html = await res.text()
      logExport.mutate({ cohortId, kind: 'one_pager' })
      w.document.open()
      w.document.write(html)
      w.document.close()
    } catch {
      fail(S.onePager.failed)
    }
  }

  return (
    <div className="flex flex-col gap-3">
      {pulse ? (
        <div className="grid gap-3 lg:grid-cols-[300px_minmax(0,1fr)]">
          <PassRateCard pulse={pulse} />
          <PulseBanner pulse={pulse} onAction={onPulseAction} />
        </div>
      ) : null}
      {belowFloor ? (
        <Alert tone="info">
          Activity statistics appear once the class reaches 5 students.
        </Alert>
      ) : null}
      <div className={showDistribution ? 'grid gap-3 lg:grid-cols-[minmax(0,1fr)_380px]' : ''}>
        {showDistribution ? (
          <Card>
            <DistributionChart distribution={distribution.data} />
          </Card>
        ) : null}
        <div className={`grid grid-cols-2 gap-3 ${showDistribution ? '' : 'sm:grid-cols-4'}`}>
          <Stat label="Students" value={o?.students ?? 0} />
          <Stat label="Active this week" value={o?.active_7d ?? 'n/a'} />
          <Stat label="Answers" value={o?.answers_total ?? 'n/a'} />
          <Stat label="Mocks completed" value={o?.mocks_completed ?? 'n/a'} />
        </div>
      </div>
      <div className="grid gap-3 lg:grid-cols-2">
        <Card>
          <h2 className="mb-4 text-base font-bold text-ink">
            Readiness by FCLE domain
          </h2>
          {domains.data ? (
            <DomainBars
              bars={domains.data.map(d => ({
                label: d.domain_name,
                value: d.accuracy,
                detail: `${d.answers} answers`,
              }))}
            />
          ) : (
            <Spinner />
          )}
        </Card>
        <Card>
          {trend.data ? <TrendChart rows={trend.data} /> : <Spinner />}
        </Card>
      </div>
      <Card>
        <h2 className="mb-3 text-base font-bold text-ink">
          Most missed questions
        </h2>
        {misses.data ? <TopMisses rows={misses.data} /> : <Spinner />}
      </Card>
      <div className="flex flex-col items-start gap-2">
        <Button variant="ghost" onClick={() => void openOnePager()}>
          Summary one-pager
        </Button>
        {onePagerError ? <Alert tone="error">{onePagerError}</Alert> : null}
      </div>
    </div>
  )
}

export function ClassView({
  cohortId,
  tab: tabProp,
  onTabChange,
}: {
  cohortId: string
  tab?: ClassTab
  onTabChange?: (tab: ClassTab) => void
}) {
  const policy = useReportingPolicy(cohortId)
  const role = useCohortRole(cohortId)
  const pulse = useCohortPulse(cohortId)
  const domains = useDomains()
  const isFaculty = role.data === 'faculty'
  const [localTab, setLocalTab] = useState<ClassTab>('overview')
  const requestedTab = tabProp ?? localTab
  const setTab = onTabChange ?? setLocalTab
  // A TA following a settings link lands on the overview, not a blank panel.
  const tab = requestedTab === 'settings' && !isFaculty ? 'overview' : requestedTab
  // The prefilled text when the dialog is open; null when closed.
  const [announcing, setAnnouncing] = useState<string | null>(null)
  // Held here so a half-built session survives tab switches (tab content
  // unmounts when inactive).
  const [liveDraft, setLiveDraft] = useState(emptyLiveDraft)

  const onPulseAction = (card: PulseCardData) => {
    if (card.kind === 'at_risk') setTab('students')
    else if (card.kind === 'weak_domain') {
      // Straight into a session scoped to the weak domain. The card names
      // the domain only in its headline ("<name> is dragging the class"); if
      // that ever stops matching, the picker just opens on all domains.
      const domain = domains.data?.find(d => card.headline.startsWith(d.name))
      setLiveDraft(d => ({ ...d, composing: true, domainId: domain?.id ?? null }))
      setTab('live')
    } else {
      setAnnouncing(
        'Quick reminder: a few minutes of FCLE practice this week keeps your projection moving.',
      )
    }
  }

  // Only faculty can message a class (the server refuses TAs).
  const visiblePulse = pulse.data && {
    ...pulse.data,
    cards: pulse.data.cards.filter(c => isFaculty || c.kind !== 'participation'),
  }

  const startLive = () => {
    setLiveDraft(d => ({ ...d, composing: true }))
    setTab('live')
  }

  return (
    <Tabs value={tab} onValueChange={t => setTab(t as ClassTab)} className="flex flex-col gap-3">
      <ClassHeader
        cohortId={cohortId}
        onMessage={isFaculty ? () => setAnnouncing('') : undefined}
        onStartLive={startLive}
        tabs={
          <TabsList aria-label="Class sections">
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="students">Students</TabsTrigger>
            <TabsTrigger value="live">Live</TabsTrigger>
            {isFaculty ? <TabsTrigger value="settings">Settings</TabsTrigger> : null}
          </TabsList>
        }
      />
      {policy.data ? <PolicyBanner policy={policy.data} /> : null}
      {announcing !== null ? (
        <MessageClassDialog
          cohortId={cohortId}
          prefill={announcing}
          open={true}
          onOpenChange={open => {
            if (!open) setAnnouncing(null)
          }}
        />
      ) : null}
      <TabsContent value="overview">
        <OverviewTab cohortId={cohortId} pulse={visiblePulse} onPulseAction={onPulseAction} />
      </TabsContent>
      <TabsContent value="students">
        <StudentsTab cohortId={cohortId} />
      </TabsContent>
      <TabsContent value="live">
        <LiveTab cohortId={cohortId} draft={liveDraft} onDraftChange={setLiveDraft} />
      </TabsContent>
      {isFaculty ? (
        <TabsContent value="settings">
          <SettingsTab cohortId={cohortId} />
        </TabsContent>
      ) : null}
    </Tabs>
  )
}
