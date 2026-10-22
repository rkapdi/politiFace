import type { ReportingPolicy } from '../lib/api'
import { S } from '../lib/strings'
import { Alert } from './ui'

const COPY: Record<ReportingPolicy['effective'], string> = {
  per_student: S.policy.perStudent,
  pseudonymous: S.policy.pseudonymous,
  aggregate_only: S.policy.aggregateOnly,
}

export function PolicyBanner({ policy }: { policy: ReportingPolicy }) {
  return <Alert tone="info">{COPY[policy.effective]}</Alert>
}
