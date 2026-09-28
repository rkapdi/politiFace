import { useMyConsoleRole } from '../lib/api'
import { Alert } from '../components/ui'
import { SkeletonStats } from '../components/Skeleton'
import { StudentHome } from '../components/StudentHome'
import { RequestAccess } from '../components/RequestAccess'
import { ClassesPage } from './ClassesPage'

/** One console, the right home per role. The server decides the role. */
export function HomePage() {
  const role = useMyConsoleRole()
  if (role.isPending) return <SkeletonStats count={2} />
  if (role.error) return <Alert tone="error">{role.error.message}</Alert>
  if (role.data === 'student') return <StudentHome />
  if (role.data === 'none') return <RequestAccess />
  return <ClassesPage />
}
