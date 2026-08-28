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
} from '../components/ui'
import { EmptyState } from '../components/EmptyState'
import {
  SkeletonChart,
  SkeletonStats,
  SkeletonTable,
} from '../components/Skeleton'
import { DomainBars } from '../components/DomainBars'
import { PulseBanner } from '../components/PulseBanner'

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
      <h1 className="text-xl font-semibold text-ink">Styleguide</h1>

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
          <label className="text-sm font-medium text-slate-700" htmlFor="sg-input">
            Email
          </label>
          <input
            id="sg-input"
            type="email"
            className="rounded-md border border-slate-300 px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-ink"
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
