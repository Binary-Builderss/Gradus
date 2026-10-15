import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { InviteAthlete } from './InviteAthlete'

const { followSelf, inviteAthlete } = vi.hoisted(() => ({
  followSelf: vi.fn(async () => {}),
  inviteAthlete: vi.fn(async () => 'invited' as const),
}))
vi.mock('@/lib/athletes', () => ({ followSelf }))
vi.mock('@/lib/invites', () => ({ inviteAthlete }))
vi.mock('@tanstack/react-router', () => ({
  Link: ({ to, children }: { to: string; children: React.ReactNode }) => <a href={to}>{children}</a>,
}))

const setup = (limit: number | null) =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <InviteAthlete limit={limit} userId="u1" userEmail="Coach@Test.dev" />
    </QueryClientProvider>,
  )

beforeEach(() => vi.clearAllMocks())

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

  it('invita un’altra persona con email e nome', async () => {
    setup(null)
    await userEvent.click(screen.getByRole('button', { name: 'Invita atleta' }))
    await userEvent.type(screen.getByLabelText("Email dell'atleta"), 'giulia@test.dev')
    await userEvent.type(screen.getByLabelText(/Nome e cognome/), 'Giulia Rossi')
    await userEvent.click(screen.getByRole('button', { name: 'Invia invito' }))
    await waitFor(() =>
      expect(inviteAthlete).toHaveBeenCalledWith({ email: 'giulia@test.dev', name: 'Giulia Rossi' }),
    )
    expect(followSelf).not.toHaveBeenCalled()
  })

  it('scrivere la propria email non invita nessuno: ti aggiunge come atleta di te stesso', async () => {
    setup(null)
    await userEvent.click(screen.getByRole('button', { name: 'Invita atleta' }))
    await userEvent.type(screen.getByLabelText("Email dell'atleta"), '  coach@test.dev ')
    await userEvent.click(screen.getByRole('button', { name: 'Invia invito' }))
    await waitFor(() => expect(followSelf).toHaveBeenCalledWith('u1'))
    expect(inviteAthlete).not.toHaveBeenCalled()
    expect(await screen.findByText(/Ora ti segui anche tu/)).toBeInTheDocument()
  })
})
