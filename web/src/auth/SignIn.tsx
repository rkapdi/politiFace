import { S } from '../lib/strings'
import { Card } from '../components/ui'
import { EmailCodeForm } from './EmailCodeForm'

export function SignIn() {
  return (
    <main className="mx-auto mt-16 max-w-sm px-4">
      <h1 className="mb-1 text-xl font-semibold text-slate-900">
        {S.signIn.title}
      </h1>
      <p className="mb-4 text-sm text-slate-500">{S.signIn.intro}</p>
      <Card>
        <EmailCodeForm />
      </Card>
    </main>
  )
}
