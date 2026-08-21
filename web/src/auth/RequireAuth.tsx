import type { ReactNode } from 'react'
import { useSession } from './SessionProvider'
import { SignIn } from './SignIn'
import { Spinner } from '../components/ui'

export function RequireAuth({ children }: { children: ReactNode }) {
  const { session, loading } = useSession()
  if (loading) return <Spinner label="Checking your session" />
  if (!session || session.user.is_anonymous) return <SignIn />
  return <>{children}</>
}
