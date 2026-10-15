import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { DisabledAccount } from './DisabledAccount'

const { setAccountDisabled } = vi.hoisted(() => ({ setAccountDisabled: vi.fn(async () => {}) }))
vi.mock('@/lib/account', () => ({ setAccountDisabled }))
vi.mock('@/components/brand', () => ({ Wordmark: () => <span>Gradus</span> }))

describe('DisabledAccount', () => {
  it('si può riattivare o uscire, nient’altro', async () => {
    const onSignOut = vi.fn()
    render(
      <QueryClientProvider client={new QueryClient()}>
        <DisabledAccount userId="u1" onSignOut={onSignOut} />
      </QueryClientProvider>,
    )
    expect(screen.getByText('Il tuo account è disattivato')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Riattiva l’account' }))
    await waitFor(() => expect(setAccountDisabled).toHaveBeenCalledWith('u1', false))
    await userEvent.click(screen.getByRole('button', { name: 'Esci' }))
    expect(onSignOut).toHaveBeenCalled()
  })
})
