import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { MesocycleStatus } from './MesocycleStatus'

const { setMesocycleStatus, deleteDraftMesocycle, navigate } = vi.hoisted(() => ({
  setMesocycleStatus: vi.fn(async () => {}),
  deleteDraftMesocycle: vi.fn(async () => {}),
  navigate: vi.fn(async () => {}),
}))
vi.mock('@/lib/mesocycles', () => ({ setMesocycleStatus, deleteDraftMesocycle }))
vi.mock('@tanstack/react-router', () => ({ useNavigate: () => navigate }))

beforeEach(() => {
  vi.clearAllMocks()
  Element.prototype.hasPointerCapture ??= () => false
  Element.prototype.releasePointerCapture ??= () => {}
  Element.prototype.scrollIntoView ??= () => {}
})

const setup = (status: 'draft' | 'active' | 'completed') =>
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MesocycleStatus mesocycle={{ id: 'm1', name: 'Blocco 1', status, athlete_id: 'a1' }} />
    </QueryClientProvider>,
  )

describe('MesocycleStatus', () => {
  it('una bozza si attiva dopo conferma, e la conferma dice cosa succede', async () => {
    setup('draft')
    expect(screen.getByText('Bozza')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Attiva' }))
    expect(await screen.findByText('Attivare «Blocco 1»?')).toBeInTheDocument()
    expect(screen.getByText(/L’atleta lo vede subito nell’app/)).toBeInTheDocument()
    expect(setMesocycleStatus).not.toHaveBeenCalled()
    await userEvent.click(screen.getAllByRole('button', { name: 'Attiva' }).at(-1)!)
    await waitFor(() => expect(setMesocycleStatus).toHaveBeenCalledWith('m1', 'active'))
  })

  it('se il database rifiuta spiega perché, con il nome del mesociclo già attivo', async () => {
    setMesocycleStatus.mockRejectedValueOnce({ message: 'athlete_has_active', hint: 'Blocco 0' })
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Attiva' }))
    await userEvent.click((await screen.findAllByRole('button', { name: 'Attiva' })).at(-1)!)
    expect(await screen.findByRole('alert')).toHaveTextContent('già un mesociclo attivo («Blocco 0»)')
  })

  it('un mesociclo vuoto non si pubblica e lo dice', async () => {
    setMesocycleStatus.mockRejectedValueOnce({ message: 'mesocycle_empty' })
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Attiva' }))
    await userEvent.click((await screen.findAllByRole('button', { name: 'Attiva' })).at(-1)!)
    expect(await screen.findByRole('alert')).toHaveTextContent('almeno una seduta con un esercizio')
  })

  it('un mesociclo attivo si conclude', async () => {
    setup('active')
    await userEvent.click(screen.getByRole('button', { name: 'Concludi' }))
    expect(await screen.findByText('Concludere «Blocco 1»?')).toBeInTheDocument()
    await userEvent.click(screen.getAllByRole('button', { name: 'Concludi' }).at(-1)!)
    await waitFor(() => expect(setMesocycleStatus).toHaveBeenCalledWith('m1', 'completed'))
  })

  it('un mesociclo attivo si può riportare in bozza dal menu', async () => {
    setup('active')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Riporta in bozza…' }))
    expect(await screen.findByText(/Si può fare solo se non ha ancora registrato/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Riporta in bozza' }))
    await waitFor(() => expect(setMesocycleStatus).toHaveBeenCalledWith('m1', 'draft'))
  })

  it('una bozza si elimina dal menu e si torna all’atleta', async () => {
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Elimina bozza…' }))
    expect(await screen.findByText('Eliminare la bozza «Blocco 1»?')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Elimina bozza' }))
    await waitFor(() => expect(deleteDraftMesocycle).toHaveBeenCalledWith('m1'))
    await waitFor(() =>
      expect(navigate).toHaveBeenCalledWith({ to: '/atleti/$athleteId', params: { athleteId: 'a1' } }),
    )
  })

  it('un mesociclo concluso non ha azioni', () => {
    setup('completed')
    expect(screen.getByText('Concluso')).toBeInTheDocument()
    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })

  it('annullare non cambia nulla', async () => {
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Attiva' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Annulla' }))
    expect(setMesocycleStatus).not.toHaveBeenCalled()
  })
})
