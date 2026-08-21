import type { ReportingPolicy } from '../lib/api'
import { Alert } from './ui'

const COPY: Record<ReportingPolicy['effective'], string> = {
  per_student: 'This class reports per-student detail to faculty.',
  pseudonymous: 'Students appear under stable pseudonyms, never names.',
  aggregate_only: 'This class reports aggregate data only.',
}

export function PolicyBanner({ policy }: { policy: ReportingPolicy }) {
  return <Alert tone="info">{COPY[policy.effective]}</Alert>
}
