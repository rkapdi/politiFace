import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

const { signInWithOtp, verifyOtp } = vi.hoisted(() => ({
  signInWithOtp: vi.fn(async () => ({ error: null })),
  verifyOtp: vi.fn(async () => ({ error: null })),
}))
vi.mock('../lib/supabase', () => ({
  supabase: { auth: { signInWithOtp, verifyOtp } },
}))

import { EmailCodeForm } from './EmailCodeForm'

describe('EmailCodeForm', () => {
  it('sends a code, then verifies it for the same trimmed email', async () => {
    render(<EmailCodeForm hint="Use your school email." />)
    expect(screen.getByText('Use your school email.')).toBeInTheDocument()
    await userEvent.type(screen.getByLabelText(/email/i), ' maria@mymdc.net ')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    expect(signInWithOtp).toHaveBeenCalledWith({ email: 'maria@mymdc.net' })
    await userEvent.type(await screen.findByLabelText(/^code$/i), '123456')
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    expect(verifyOtp).toHaveBeenCalledWith({
      email: 'maria@mymdc.net',
      token: '123456',
      type: 'email',
    })
  })

  it('shows an error when the code does not match', async () => {
    verifyOtp.mockResolvedValueOnce({ error: { message: 'bad' } } as never)
    render(<EmailCodeForm />)
    await userEvent.type(screen.getByLabelText(/email/i), 'a@b.co')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    await userEvent.type(await screen.findByLabelText(/^code$/i), '000000')
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    expect(await screen.findByRole('alert')).toHaveTextContent(/did not match/i)
  })

  it('shows a rate-limit message, not "bad email", when sending is throttled', async () => {
    signInWithOtp.mockResolvedValueOnce({
      error: { message: 'rate limited', status: 429 },
    } as never)
    render(<EmailCodeForm />)
    await userEvent.type(screen.getByLabelText(/email/i), 'a@b.co')
    await userEvent.click(screen.getByRole('button', { name: /send code/i }))
    expect(await screen.findByRole('alert')).toHaveTextContent(/too many codes/i)
  })

  it('re-enables the send button if signInWithOtp throws', async () => {
    signInWithOtp.mockRejectedValueOnce(new Error('boom'))
    render(<EmailCodeForm />)
    await userEvent.type(screen.getByLabelText(/email/i), 'a@b.co')
    const button = screen.getByRole('button', { name: /send code/i })
    await userEvent.click(button)
    expect(await screen.findByRole('alert')).toHaveTextContent(/could not send/i)
    expect(button).not.toBeDisabled()
  })
})
