import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { InviteAthlete } from './InviteAthlete'

vi.mock('@/lib/supabase', () => ({ supabase: {} }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, children }: { to: string; children: React.ReactNode }) => <a href={to}>{children}</a>,
}))

const setup = (limit: number | null) =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <InviteAthlete limit={limit} />
    </QueryClientProvider>,
  )

describe('InviteAthlete', () => {
  it('con posti liberi si può invitare', () => {
    setup(null)
    expect(screen.getByRole('button', { name: 'Invita atleta' })).toBeEnabled()
  })

  it('a tetto raggiunto il pulsante è spento e rimanda ai piani', () => {
    setup(20)
    expect(screen.getByRole('button', { name: 'Invita atleta' })).toBeDisabled()
    expect(screen.getByText(/Hai raggiunto il limite di 20 atleti del tuo piano/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Vedi i piani' })).toHaveAttribute('href', '/piani')
  })
})
