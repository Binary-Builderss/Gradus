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

const setup = (limit: number | null, seats?: { used: number; limit: number | null; near: boolean }) =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <InviteAthlete limit={limit} userId="u1" userEmail="Coach@Test.dev" seats={seats} />
    </QueryClientProvider>,
  )

beforeEach(() => vi.clearAllMocks())

describe('InviteAthlete', () => {
  it('con posti liberi si può invitare', () => {
    setup(null)
    expect(screen.getByRole('button', { name: 'Invita atleta' })).toBeEnabled()
  })

  it('dice quanti posti sono usati, e rimanda ai piani solo quando restano pochi', () => {
    const { unmount } = setup(null, { used: 12, limit: 20, near: false })
    expect(screen.getByText('12 di 20 atleti')).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Più posti' })).not.toBeInTheDocument()
    unmount()
    setup(null, { used: 17, limit: 20, near: true })
    expect(screen.getByText(/17 di 20 atleti/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Più posti' })).toHaveAttribute('href', '/piani')
  })

  it('se il tetto non è noto conta solo gli atleti', () => {
    setup(null, { used: 130, limit: null, near: false })
    expect(screen.getByText('130 atleti')).toBeInTheDocument()
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
