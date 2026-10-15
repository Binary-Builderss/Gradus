import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ProgressionWeek } from '@/lib/blocks'
import { ProgressionForm } from './ProgressionForm'

const { applyProgression, previewProgression } = vi.hoisted(() => ({
  applyProgression: vi.fn(async (): Promise<number> => 4),
  previewProgression: vi.fn(async (): Promise<ProgressionWeek[]> => []),
}))
vi.mock('@/lib/blocks', () => ({ applyProgression, previewProgression }))

const cell = (sets: number, value: number | null = null) => ({
  sets,
  repsMin: 8,
  repsMax: 10,
  method: value === null ? null : ('BUF' as const),
  value,
  refPct: null,
})

function setup() {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <ProgressionForm mesocycleId="m1" blockId="b1" />
    </QueryClientProvider>,
  )
}
const group = (name: string) => within(screen.getByRole('group', { name }))

beforeEach(() => {
  applyProgression.mockClear()
  previewProgression.mockClear()
  previewProgression.mockResolvedValue([])
})

describe('ProgressionForm', () => {
  it('senza le serie della prima settimana non applica e non calcola l’anteprima', async () => {
    setup()
    expect(screen.getByText(/Indica le serie della prima settimana per vedere/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Applica' }))
    expect(await screen.findByText('Indica le serie della prima settimana.')).toBeInTheDocument()
    expect(applyProgression).not.toHaveBeenCalled()
    expect(previewProgression).not.toHaveBeenCalled()
  })

  it('manda la regola alla funzione e mostra le settimane scritte', async () => {
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    await userEvent.type(group('Serie').getByLabelText('Cambia di'), '1')
    await userEvent.selectOptions(screen.getByLabelText('Misura'), 'BUF')
    await userEvent.type(group('Sforzo').getByLabelText('Parti da'), '3')
    await userEvent.type(group('Sforzo').getByLabelText('Cambia di'), '-1')
    await userEvent.click(screen.getByRole('button', { name: /^Applica/ }))
    await waitFor(() => expect(applyProgression).toHaveBeenCalledTimes(1))
    expect(applyProgression).toHaveBeenCalledWith('b1', {
      sets: { start: 3, step: 1 },
      method: 'BUF',
      intensity: { start: 3, step: -1 },
    })
    expect(await screen.findByText('Scritte 4 settimane.')).toBeInTheDocument()
  })

  it('anteprima settimana per settimana: scritte, scarico saltato, già eseguite intatte', async () => {
    previewProgression.mockResolvedValue([
      { week: 1, action: 'locked', cell: cell(3, 3) },
      { week: 2, action: 'write', cell: cell(4, 2) },
      { week: 3, action: 'deload', cell: cell(2) },
    ])
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    expect(await screen.findByText('Già eseguita: resta com’è')).toBeInTheDocument()
    expect(screen.getByText('4 serie da 8-10 ripetizioni, 2 ripetizioni in riserva')).toBeInTheDocument()
    expect(screen.getByText('Scarico: non viene toccata')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Applica a 1 settimana' })).toBeInTheDocument()
    expect(previewProgression).toHaveBeenLastCalledWith('b1', { sets: { start: 3 } })
  })

  it('un esempio compila i campi e ne mostra l’effetto', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Una serie in più a settimana' }))
    expect(group('Serie').getByLabelText('Parti da')).toHaveValue('3')
    expect(group('Serie').getByLabelText('Cambia di')).toHaveValue('1')
    expect(group('Serie').getByLabelText('Non superare')).toHaveValue('5')
    await waitFor(() =>
      expect(previewProgression).toHaveBeenCalledWith('b1', { sets: { start: 3, step: 1, max: 5 } }),
    )
  })

  it('misura senza valore: errore, nessuna chiamata', async () => {
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    await userEvent.selectOptions(screen.getByLabelText('Misura'), 'RPE')
    await userEvent.click(screen.getByRole('button', { name: 'Applica' }))
    expect(await screen.findByText('Misura e valore di partenza vanno insieme.')).toBeInTheDocument()
    expect(applyProgression).not.toHaveBeenCalled()
  })

  it('errore del server: messaggio chiaro', async () => {
    applyProgression.mockRejectedValueOnce(new Error('22023'))
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    await userEvent.click(screen.getByRole('button', { name: /^Applica/ }))
    expect(await screen.findByText(/Non sono riuscito ad applicare/)).toBeInTheDocument()
  })

  it('anteprima in errore: messaggio, ma si può ancora applicare', async () => {
    previewProgression.mockRejectedValue(new Error('23514'))
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    expect(await screen.findByText(/Non riesco a calcolare l’anteprima/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Applica' })).toBeEnabled()
  })
})
