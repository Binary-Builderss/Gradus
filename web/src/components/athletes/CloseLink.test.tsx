import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { CloseLink } from './CloseLink'

const { endLink, navigate } = vi.hoisted(() => ({ endLink: vi.fn(async () => {}), navigate: vi.fn() }))
vi.mock('@/lib/athletes', () => ({ endLink }))
vi.mock('@tanstack/react-router', () => ({ useNavigate: () => navigate }))

const setup = () =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <CloseLink coachId="c1" athleteId="a1" name="Marco Rossi" />
    </QueryClientProvider>,
  )
beforeEach(() => vi.clearAllMocks())

async function openDialog() {
  await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
  await userEvent.click(await screen.findByRole('menuitem', { name: 'Chiudi il collegamento' }))
}

describe('CloseLink', () => {
  it('chiede conferma e dice cosa cambia, senza chiudere subito', async () => {
    setup()
    await openDialog()
    expect(await screen.findByText('Chiudere il collegamento con Marco Rossi?')).toBeInTheDocument()
    expect(screen.getByText(/Non cancella nulla/)).toBeInTheDocument()
    expect(screen.getByText(/Si libera un posto/)).toBeInTheDocument()
    expect(endLink).not.toHaveBeenCalled()
  })

  it('annullando non chiude nulla', async () => {
    setup()
    await openDialog()
    await userEvent.click(await screen.findByRole('button', { name: 'Annulla' }))
    expect(endLink).not.toHaveBeenCalled()
  })

  it('confermando chiude il collegamento e torna all’elenco', async () => {
    setup()
    await openDialog()
    await userEvent.click(await screen.findByRole('button', { name: 'Chiudi il collegamento' }))
    await waitFor(() => expect(endLink).toHaveBeenCalledWith('c1', 'a1'))
    await waitFor(() => expect(navigate).toHaveBeenCalledWith({ to: '/' }))
  })

  it('errore: messaggio chiaro e si resta sulla scheda', async () => {
    endLink.mockRejectedValueOnce(new Error('x'))
    setup()
    await openDialog()
    await userEvent.click(await screen.findByRole('button', { name: 'Chiudi il collegamento' }))
    expect(await screen.findByText(/Non sono riuscito a chiudere il collegamento/)).toBeInTheDocument()
    expect(navigate).not.toHaveBeenCalled()
  })
})
