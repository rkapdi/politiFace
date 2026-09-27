import { useState } from 'react'
import { useParams } from '@tanstack/react-router'
import {
  useCohortDistribution,
  useCohortOverview,
  useCohortPulse,
  useCohortRole,
  useDomainStats,
  useEngagementTrend,
  useLogExport,
  useReportingPolicy,
  useTopMisses,
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
import { SkeletonChart, SkeletonStats } from '../components/Skeleton'
import { DomainBars } from '../components/DomainBars'
import { TrendChart } from '../components/TrendChart'
import { TopMisses } from '../components/TopMisses'
import { StudentsTab } from '../components/StudentsTab'
import { SettingsTab } from '../components/SettingsTab'
import { LiveTab, emptyLiveDraft } from '../components/LiveTab'
import { PulseBanner } from '../components/PulseBanner'
import { DistributionChart } from '../components/DistributionChart'
import { MessageClassDialog } from './StudentPage'

export function ClassPage() {
  const { cohortId } = useParams({ strict: false }) as { cohortId: string }
  return <ClassView cohortId={cohortId} />
}

function OverviewTab({ cohortId }: { cohortId: string }) {
  const overview = useCohortOverview(cohortId)
  const domains = useDomainStats(cohortId)
  const misses = useTopMisses(cohortId)
  const trend = useEngagementTrend(cohortId)
  const distribution = useCohortDistribution(cohortId)
  const logExport = useLogExport()
  const [onePagerError, setOnePagerError] = useState<string | null>(null)

  if (overview.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <SkeletonStats />
        <SkeletonChart />
      </div>
    )
  }
  if (overview.error) return <Alert tone="error">{overview.error.message}</Alert>

  const o = overview.data
  const belowFloor = o !== undefined && o.active_7d === null

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
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Stat label="Students" value={o?.students ?? 0} />
        <Stat label="Active this week" value={o?.active_7d ?? 'n/a'} />
        <Stat label="Answers" value={o?.answers_total ?? 'n/a'} />
        <Stat label="Mocks completed" value={o?.mocks_completed ?? 'n/a'} />
      </div>
      {belowFloor ? (
        <Alert tone="info">
          Activity statistics appear once the class reaches 5 students.
        </Alert>
      ) : null}
      {distribution.data && !distribution.data.below_floor ? (
        <Card>
          <DistributionChart distribution={distribution.data} />
        </Card>
      ) : null}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-900">
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
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
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

export function ClassView({ cohortId }: { cohortId: string }) {
  const policy = useReportingPolicy(cohortId)
  const role = useCohortRole(cohortId)
  const pulse = useCohortPulse(cohortId)
  const isFaculty = role.data === 'faculty'
  const [tab, setTab] = useState('overview')
  const [announcing, setAnnouncing] = useState(false)
  // Held here so a half-built session survives tab switches (tab content
  // unmounts when inactive).
  const [liveDraft, setLiveDraft] = useState(emptyLiveDraft)

  const onPulseAction = (kind: PulseCardData['kind']) => {
    if (kind === 'at_risk') setTab('students')
    else if (kind === 'weak_domain') setTab('live')
    else setAnnouncing(true)
  }

  return (
    <div className="flex flex-col gap-4">
      {policy.data ? <PolicyBanner policy={policy.data} /> : null}
      {pulse.data ? (
        <PulseBanner pulse={pulse.data} onAction={onPulseAction} />
      ) : null}
      {announcing ? (
        <MessageClassDialog
          cohortId={cohortId}
          prefill="Quick reminder: a few minutes of FCLE practice this week keeps your projection moving."
          open={true}
          onOpenChange={open => {
            if (!open) setAnnouncing(false)
          }}
        />
      ) : null}
      <Tabs value={tab} onValueChange={setTab}>
        <TabsList aria-label="Class sections">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="students">Students</TabsTrigger>
          <TabsTrigger value="live">Live</TabsTrigger>
          {isFaculty ? <TabsTrigger value="settings">Settings</TabsTrigger> : null}
        </TabsList>
        <TabsContent value="overview">
          <OverviewTab cohortId={cohortId} />
        </TabsContent>
        <TabsContent value="students">
          <StudentsTab cohortId={cohortId} />
        </TabsContent>
        <TabsContent value="live">
          <LiveTab
            cohortId={cohortId}
            draft={liveDraft}
            onDraftChange={setLiveDraft}
          />
        </TabsContent>
        {isFaculty ? (
          <TabsContent value="settings">
            <SettingsTab cohortId={cohortId} />
          </TabsContent>
        ) : null}
      </Tabs>
    </div>
  )
}
