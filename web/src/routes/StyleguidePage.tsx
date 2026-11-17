// The living component gallery: every shared component in every
// interactive state, in one place. Doubles as the interactive-state
// coverage evidence for the VPAT.
import { Download, Users } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Card,
  Spinner,
  Stat,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
  fieldClass,
} from '../components/ui'
import { ThemePicker } from '../components/ThemePicker'
import { DistributionChart } from '../components/DistributionChart'
import { TrendChart } from '../components/TrendChart'
import { StudentTrendChart } from '../components/StudentTrendChart'
import { Scoreboard } from '../components/Scoreboard'
import { TopMisses } from '../components/TopMisses'
import { EmptyState } from '../components/EmptyState'
import {
  SkeletonChart,
  SkeletonStats,
  SkeletonTable,
} from '../components/Skeleton'
import { DomainBars } from '../components/DomainBars'
import { PulseBanner } from '../components/PulseBanner'
import { PassRateCard } from './ClassPage'

function Section({
  title,
  children,
}: {
  title: string
  children: React.ReactNode
}) {
  return (
    <section aria-label={title} className="flex flex-col gap-3">
      <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">
        {title}
      </h2>
      {children}
    </section>
  )
}

export function StyleguidePage() {
  return (
    <div className="flex flex-col gap-8">
      <h1 className="text-[28px] font-bold leading-tight tracking-[-0.03em] text-ink">Styleguide</h1>

      <Section title="Theme">
        <Card>
          <ThemePicker />
        </Card>
      </Section>

      <Section title="Tabs">
        <Tabs defaultValue="overview" className="flex flex-col items-start gap-3">
          <TabsList aria-label="Example tabs">
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="students">Students</TabsTrigger>
            <TabsTrigger value="live">Live</TabsTrigger>
          </TabsList>
          <TabsContent value="overview" className="text-sm text-ink-2">Overview panel</TabsContent>
          <TabsContent value="students" className="text-sm text-ink-2">Students panel</TabsContent>
          <TabsContent value="live" className="text-sm text-ink-2">Live panel</TabsContent>
        </Tabs>
      </Section>

      <Section title="Buttons">
        <div className="flex flex-wrap items-center gap-3">
          <Button>Primary</Button>
          <Button variant="ghost">Ghost</Button>
          <Button variant="danger">Danger</Button>
          <Button disabled>Disabled</Button>
          <Button variant="ghost">
            <Download aria-hidden="true" className="size-4" />
            With icon
          </Button>
        </div>
      </Section>

      <Section title="Badges">
        <div className="flex flex-wrap gap-2">
          <Badge>Neutral</Badge>
          <Badge tone="green">52 of 80</Badge>
          <Badge tone="amber">44 of 80</Badge>
          <Badge tone="red">28 of 80</Badge>
        </div>
      </Section>

      <Section title="Alerts">
        <Alert tone="error">Something went wrong on our side. Try again.</Alert>
        <Alert tone="success">Policy saved.</Alert>
        <Alert tone="info">This class reports aggregate data only.</Alert>
      </Section>

      <Section title="Form fields">
        <div className="flex max-w-xs flex-col gap-2">
          <label className="text-sm font-medium text-ink-2" htmlFor="sg-input">
            Email
          </label>
          <input
            id="sg-input"
            type="email"
            className={fieldClass}
          />
        </div>
      </Section>

      <Section title="Stat">
        <div className="grid max-w-xl grid-cols-2 gap-4">
          <Stat label="Students" value={32} />
          <Stat label="Accuracy" value="71%" hint="480 answers total" />
        </div>
      </Section>

      <Section title="Domain bars">
        <Card>
          <DomainBars
            bars={[
              { label: 'American Democracy', value: 0.72 },
              { label: 'U.S. Constitution', value: 0.46 },
              { label: 'No data domain', value: null },
            ]}
          />
        </Card>
      </Section>

      <Section title="Charts">
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <DistributionChart
              distribution={{
                students: 32,
                pass_line: 48,
                avg: 51,
                bins: { '20-29': 2, '30-39': 4, '40-49': 6, '50-59': 9, '60-69': 8, '70-80': 3 },
              }}
            />
          </Card>
          <Card>
            <TrendChart
              rows={[
                { day: '2026-11-08', answers: 110, active_students: 14 },
                { day: '2026-11-09', answers: 143, active_students: 17 },
                { day: '2026-11-10', answers: 162, active_students: 21 },
                { day: '2026-11-11', answers: 134, active_students: 18 },
                { day: '2026-11-12', answers: 190, active_students: 24 },
              ]}
            />
          </Card>
          <Card>
            <StudentTrendChart
              trend={{
                pass_line: 48,
                weeks: [
                  { week_start: '2026-10-12', projected: 38, answers: 40, accuracy: 0.6 },
                  { week_start: '2026-10-19', projected: 42, answers: 61, accuracy: 0.6 },
                  { week_start: '2026-10-26', projected: 45, answers: 58, accuracy: 0.6 },
                  { week_start: '2026-11-02', projected: 51, answers: 77, accuracy: 0.6 },
                ],
              }}
            />
          </Card>
          <Card>
            <Scoreboard
              rows={[
                { rank: 1, handle: 'Hana S.', score: 3920, correct_count: 4, is_me: false },
                { rank: 2, handle: 'You', score: 3640, correct_count: 4, is_me: true },
                { rank: 3, handle: 'Zoe P.', score: 3400, correct_count: 3, is_me: false },
              ]}
            />
          </Card>
        </div>
        <Card>
          <TopMisses
            rows={[
              { question_id: 'q1', stem: 'Which Federalist paper addresses the danger of factions?', domain_code: 'FD', students: 29, attempts: 58, miss_rate: 0.62 },
            ]}
          />
        </Card>
      </Section>

      <Section title="Overview top row">
        <div className="grid gap-3 lg:grid-cols-[300px_minmax(0,1fr)]">
          <PassRateCard
            pulse={{ students: 32, above_line: 18, sentence: '', cards: [] }}
          />
          <PulseBanner
            pulse={{
              students: 32,
              sentence:
                '18 of 32 students project above the pass line. U.S. Constitution is the weakest domain at 46%.',
              cards: [],
            }}
            onAction={() => {}}
          />
        </div>
      </Section>

      <Section title="Pulse">
        <PulseBanner
          pulse={{
            students: 32,
            sentence:
              '18 of 32 students project above the pass line. U.S. Constitution is the weakest domain at 46%. 12 of 32 practiced this week.',
            cards: [
              {
                kind: 'at_risk',
                headline: '14 students project below the pass line',
                detail: 'The Students tab ranks them lowest readiness first.',
              },
            ],
          }}
          onAction={() => {}}
        />
      </Section>

      <Section title="Empty state">
        <EmptyState
          icon={Users}
          title="No students yet"
          hint="Share the class join code and students appear here as they enroll."
          actionLabel="Copy join code"
          onAction={() => {}}
        />
      </Section>

      <Section title="Loading">
        <div className="flex flex-col gap-4">
          <Spinner label="Inline loading" />
          <SkeletonStats count={2} />
          <SkeletonTable rows={2} />
          <SkeletonChart height="h-20" />
        </div>
      </Section>
    </div>
  )
}
