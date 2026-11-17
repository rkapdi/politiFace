import { PublicPage } from '../components/Brand'
import { S } from '../lib/strings'
import { Card } from '../components/ui'
import { EmailCodeForm } from './EmailCodeForm'

export function SignIn() {
  return (
    <PublicPage>
      <h1 className="px-1.5 text-[28px] font-bold leading-tight tracking-[-0.03em] text-ink">
        {S.signIn.title}
      </h1>
      <p className="px-1.5 text-sm text-ink-2">{S.signIn.intro}</p>
      <Card>
        <EmailCodeForm />
      </Card>
    </PublicPage>
  )
}
