import { useParams } from '@tanstack/react-router'
import {
  useCohortOverview,
  useCohortRole,
  useDomainStats,
  useEngagementTrend,
  useLogExport,
  useReportingPolicy,
  useTopMisses,
} from '../lib/api'
import { supabase } from '../lib/supabase'
import { SUPABASE_URL } from '../lib/config'
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
import { DomainBars } from '../components/DomainBars'
import { TrendChart } from '../components/TrendChart'
import { TopMisses } from '../components/TopMisses'
import { StudentsTab } from '../components/StudentsTab'
import { SettingsTab } from '../components/SettingsTab'
import { LiveTab } from '../components/LiveTab'

export function ClassPage() {
  const { cohortId } = useParams({ strict: false }) as { cohortId: string }
  return <ClassView cohortId={cohortId} />
}

function OverviewTab({ cohortId }: { cohortId: string }) {
  const overview = useCohortOverview(cohortId)
  const domains = useDomainStats(cohortId)
  const misses = useTopMisses(cohortId)
  const trend = useEngagementTrend(cohortId)
  const logExport = useLogExport()

  if (overview.isPending) return <Spinner label="Loading class analytics" />
  if (overview.error) return <Alert tone="error">{overview.error.message}</Alert>

  const o = overview.data
  const belowFloor = o !== undefined && o.active_7d === null

  const openOnePager = async () => {
    const { data } = await supabase.auth.getSession()
    const token = data.session?.access_token
    if (!token) return
    logExport.mutate({ cohortId, kind: 'one_pager' })
    const res = await fetch(
      `${SUPABASE_URL}/functions/v1/efficacy-report?cohort=${cohortId}`,
      { headers: { Authorization: `Bearer ${token}` } },
    )
    const html = await res.text()
    const w = window.open('', '_blank')
    if (w) {
      w.document.write(html)
      w.document.close()
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
      <div>
        <Button variant="ghost" onClick={() => void openOnePager()}>
          Summary one-pager
        </Button>
      </div>
    </div>
  )
}

export function ClassView({ cohortId }: { cohortId: string }) {
  const policy = useReportingPolicy(cohortId)
  const role = useCohortRole(cohortId)
  const isFaculty = role.data === 'faculty'

  return (
    <div className="flex flex-col gap-4">
      {policy.data ? <PolicyBanner policy={policy.data} /> : null}
      <Tabs defaultValue="overview">
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
          <LiveTab cohortId={cohortId} />
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
