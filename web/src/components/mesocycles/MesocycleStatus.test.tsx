import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { MesocycleStatus } from './MesocycleStatus'

const { setMesocycleStatus, deleteDraftMesocycle, cloneMesocycle, saveAsTemplate, navigate } = vi.hoisted(
  () => ({
    setMesocycleStatus: vi.fn(async () => {}),
    deleteDraftMesocycle: vi.fn(async () => {}),
    cloneMesocycle: vi.fn(async () => 'm2'),
    saveAsTemplate: vi.fn(async () => 't1'),
    navigate: vi.fn(async () => {}),
  }),
)
vi.mock('@/lib/mesocycles', () => ({ setMesocycleStatus, deleteDraftMesocycle, cloneMesocycle }))
vi.mock('@/lib/templates', () => ({ saveAsTemplate }))
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
      <MesocycleStatus mesocycle={{ id: 'm1', name: 'Blocco 1', status, athlete_id: 'a1' }} coachId="c1" />
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

  it('un mesociclo concluso non ha azioni di stato, ma si può duplicare e salvare come template', async () => {
    setup('completed')
    expect(screen.getByText('Concluso')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Concludi' })).not.toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    expect(await screen.findByRole('menuitem', { name: 'Duplica…' })).toBeInTheDocument()
    expect(screen.getByRole('menuitem', { name: 'Salva come template…' })).toBeInTheDocument()
    expect(screen.queryByRole('menuitem', { name: /Riporta in bozza|Elimina bozza/ })).not.toBeInTheDocument()
  })

  it('duplica: chiede data e nome, crea la copia e ci porta dentro', async () => {
    setup('active')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Duplica…' }))
    expect(await screen.findByText('Duplicare «Blocco 1»?')).toBeInTheDocument()
    expect(screen.getByText(/Le sedute già registrate non si copiano/)).toBeInTheDocument()
    fireEvent.change(screen.getByLabelText('Data di inizio'), { target: { value: '2026-12-07' } })
    await userEvent.type(screen.getByLabelText('Nome (facoltativo)'), 'Blocco 2')
    await userEvent.click(screen.getByRole('button', { name: 'Duplica' }))
    await waitFor(() =>
      expect(cloneMesocycle).toHaveBeenCalledWith('m1', { start_date: '2026-12-07', name: 'Blocco 2' }),
    )
    await waitFor(() =>
      expect(navigate).toHaveBeenCalledWith({ to: '/mesocicli/$mesocycleId', params: { mesocycleId: 'm2' } }),
    )
  })

  it('duplica senza nome: il nome lo decide il database («Copia di …»)', async () => {
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Duplica…' }))
    expect(await screen.findByPlaceholderText('Copia di Blocco 1')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Duplica' }))
    await waitFor(() =>
      expect(cloneMesocycle).toHaveBeenCalledWith('m1', { start_date: expect.any(String), name: '' }),
    )
  })

  it('duplica: senza data non parte', async () => {
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Duplica…' }))
    fireEvent.change(await screen.findByLabelText('Data di inizio'), { target: { value: '' } })
    await userEvent.click(screen.getByRole('button', { name: 'Duplica' }))
    expect(await screen.findByText('Scegli la data di inizio.')).toBeInTheDocument()
    expect(cloneMesocycle).not.toHaveBeenCalled()
  })

  it('salva come template: nome e descrizione, poi conferma', async () => {
    setup('active')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Salva come template…' }))
    expect(await screen.findByText('Salvare «Blocco 1» come template?')).toBeInTheDocument()
    expect(screen.getByText(/il template non cambia/)).toBeInTheDocument()
    expect(screen.getByLabelText('Nome del template')).toHaveValue('Blocco 1')
    await userEvent.type(screen.getByLabelText('Descrizione (facoltativa)'), 'Per ipertrofia')
    await userEvent.click(screen.getByRole('button', { name: 'Salva template' }))
    await waitFor(() =>
      expect(saveAsTemplate).toHaveBeenCalledWith('m1', { name: 'Blocco 1', description: 'Per ipertrofia' }),
    )
    expect(
      await screen.findByText('Template «Blocco 1» salvato. Lo trovi nella sezione Template.'),
    ).toBeInTheDocument()
  })

  it('salva come template: un nome già usato lo dice, senza nome non parte', async () => {
    saveAsTemplate.mockRejectedValueOnce({ code: '23505' })
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Altre azioni' }))
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Salva come template…' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Salva template' }))
    expect(await screen.findByText('Hai già un template con questo nome.')).toBeInTheDocument()
    await userEvent.clear(screen.getByLabelText('Nome del template'))
    await userEvent.click(screen.getByRole('button', { name: 'Salva template' }))
    expect(await screen.findByText('Dai un nome al template.')).toBeInTheDocument()
    expect(saveAsTemplate).toHaveBeenCalledTimes(1)
  })

  it('annullare non cambia nulla', async () => {
    setup('draft')
    await userEvent.click(screen.getByRole('button', { name: 'Attiva' }))
    await userEvent.click(await screen.findByRole('button', { name: 'Annulla' }))
    expect(setMesocycleStatus).not.toHaveBeenCalled()
  })
})
