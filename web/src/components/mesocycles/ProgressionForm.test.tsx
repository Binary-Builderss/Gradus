import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ProgressionWeek } from '@/lib/blocks'
import { ProgressionForm } from './ProgressionForm'

const { applyProgression, previewProgression, presets, savePreset, deletePreset } = vi.hoisted(() => ({
  applyProgression: vi.fn(async (): Promise<number> => 4),
  previewProgression: vi.fn(async (): Promise<ProgressionWeek[]> => []),
  presets: { list: [] as { id: string; name: string; rule: unknown }[] },
  savePreset: vi.fn(async () => {}),
  deletePreset: vi.fn(async () => {}),
}))
vi.mock('@/lib/blocks', () => ({ applyProgression, previewProgression }))
vi.mock('@/lib/progressionPresets', () => ({
  progressionPresetsQuery: () => ({
    queryKey: ['progression-presets', 'c1'],
    queryFn: async () => presets.list,
  }),
  savePreset,
  deletePreset,
}))

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
      <ProgressionForm coachId="c1" mesocycleId="m1" blockId="b1" />
    </QueryClientProvider>,
  )
}
const group = (name: string) => within(screen.getByRole('group', { name }))

beforeEach(() => {
  presets.list = []
  savePreset.mockClear()
  deletePreset.mockClear()
  applyProgression.mockClear()
  previewProgression.mockClear()
  previewProgression.mockResolvedValue([])
})

describe('ProgressionForm', () => {
  it('senza le serie della prima settimana non applica e non calcola l’anteprima', async () => {
    setup()
    expect(screen.getByText(/Indica le serie della prima settimana per vedere/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Applica progressione' }))
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
    await userEvent.click(screen.getByRole('button', { name: /^Applica progressione/ }))
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
    expect(screen.getByRole('button', { name: 'Applica progressione a 1 settimana' })).toBeInTheDocument()
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
    await userEvent.click(screen.getByRole('button', { name: 'Applica progressione' }))
    expect(await screen.findByText('Misura e valore di partenza vanno insieme.')).toBeInTheDocument()
    expect(applyProgression).not.toHaveBeenCalled()
  })

  it('errore del server: messaggio chiaro', async () => {
    applyProgression.mockRejectedValueOnce(new Error('22023'))
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    await userEvent.click(screen.getByRole('button', { name: /^Applica progressione/ }))
    expect(await screen.findByText(/Non sono riuscito ad applicare/)).toBeInTheDocument()
  })

  it('anteprima in errore: messaggio, ma si può ancora applicare', async () => {
    previewProgression.mockRejectedValue(new Error('23514'))
    setup()
    await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
    expect(await screen.findByText(/Non riesco a calcolare l’anteprima/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Applica progressione' })).toBeEnabled()
  })

  describe('modelli salvati', () => {
    const saved = {
      id: 'p1',
      name: 'Sforzo che sale',
      rule: { sets: { start: 3 }, method: 'BUF', intensity: { start: 3, step: -1, min: 0 } },
    }

    it('senza modelli spiega come crearne uno', async () => {
      setup()
      expect(await screen.findByText(/Nessun modello salvato/)).toBeInTheDocument()
    })

    it('un modello salvato compila i campi e se ne vede l’effetto', async () => {
      presets.list = [saved]
      setup()
      await userEvent.click(await screen.findByRole('button', { name: 'Sforzo che sale' }))
      expect(group('Serie').getByLabelText('Parti da')).toHaveValue('3')
      expect(screen.getByLabelText('Misura')).toHaveValue('BUF')
      expect(group('Sforzo').getByLabelText('Cambia di')).toHaveValue('-1')
      await waitFor(() =>
        expect(previewProgression).toHaveBeenCalledWith('b1', {
          sets: { start: 3 },
          method: 'BUF',
          intensity: { start: 3, step: -1, min: 0 },
        }),
      )
    })

    it('salva la progressione compilata con il nome scelto', async () => {
      setup()
      await userEvent.type(group('Serie').getByLabelText('Parti da'), '4')
      await userEvent.type(group('Serie').getByLabelText('Cambia di'), '1')
      await userEvent.type(screen.getByLabelText('Nome del modello'), '  Più serie  ')
      await userEvent.click(screen.getByRole('button', { name: 'Salva modello' }))
      await waitFor(() =>
        expect(savePreset).toHaveBeenCalledWith('c1', 'Più serie', { sets: { start: 4, step: 1 } }),
      )
      expect(await screen.findByText('Modello «Più serie» salvato.')).toBeInTheDocument()
    })

    it('senza nome o con la progressione incompleta non salva', async () => {
      setup()
      await userEvent.click(screen.getByRole('button', { name: 'Salva modello' }))
      expect(await screen.findByText('Dai un nome al modello.')).toBeInTheDocument()
      await userEvent.type(screen.getByLabelText('Nome del modello'), 'Vuoto')
      await userEvent.click(screen.getByRole('button', { name: 'Salva modello' }))
      expect(await screen.findByText(/Completa prima la progressione/)).toBeInTheDocument()
      expect(savePreset).not.toHaveBeenCalled()
    })

    it('un nome già usato dà un messaggio chiaro', async () => {
      savePreset.mockRejectedValueOnce({ code: '23505' })
      setup()
      await userEvent.type(group('Serie').getByLabelText('Parti da'), '3')
      await userEvent.type(screen.getByLabelText('Nome del modello'), 'Doppio')
      await userEvent.click(screen.getByRole('button', { name: 'Salva modello' }))
      expect(await screen.findByText('Hai già un modello con questo nome.')).toBeInTheDocument()
    })

    it('elimina un modello', async () => {
      presets.list = [saved]
      setup()
      await userEvent.click(await screen.findByRole('button', { name: 'Elimina il modello Sforzo che sale' }))
      await waitFor(() => expect(deletePreset).toHaveBeenCalledWith('c1', 'p1'))
    })
  })
})
