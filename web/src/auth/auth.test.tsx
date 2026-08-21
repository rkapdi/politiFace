import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const { signInWithOtp, verifyOtp } = vi.hoisted(() => ({
  signInWithOtp: vi.fn(async () => ({ error: null })),
  verifyOtp: vi.fn(async () => ({ data: {}, error: null })),
}))
vi.mock('../lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: async () => ({ data: { session: null } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      signInWithOtp,
      verifyOtp,
    },
  },
}))

import { SessionProvider } from './SessionProvider'
import { RequireAuth } from './RequireAuth'

describe('auth shell', () => {
  it('gates content behind sign-in and starts the OTP flow', async () => {
    render(
      <SessionProvider>
        <RequireAuth>
          <p>secret</p>
        </RequireAuth>
      </SessionProvider>,
    )
    expect(screen.queryByText('secret')).toBeNull()
    const email = await screen.findByLabelText(/email/i)
    await userEvent.type(email, 'prof@example.edu')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    expect(signInWithOtp).toHaveBeenCalledWith({ email: 'prof@example.edu' })
    expect(await screen.findByLabelText(/code/i)).toBeInTheDocument()
  })
})
