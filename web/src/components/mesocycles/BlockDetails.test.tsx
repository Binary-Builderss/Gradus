import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { BlockData } from '@/lib/gridModel'
import { BlockDetails } from './BlockDetails'

const { updateBlock } = vi.hoisted(() => ({ updateBlock: vi.fn(async () => undefined) }))
vi.mock('@/lib/progressionPresets', () => ({
  progressionPresetsQuery: () => ({ queryKey: ['progression-presets', 'c1'], queryFn: async () => [] }),
  savePreset: vi.fn(),
  deletePreset: vi.fn(),
}))
vi.mock('@/lib/blocks', () => ({
  updateBlock,
  deleteBlock: vi.fn(),
  applyProgression: vi.fn(),
  previewProgression: vi.fn(async () => []),
  ROLES: ['working', 'warmup', 'top', 'backoff'],
  TECHNIQUES: ['none', 'drop', 'rest_pause', 'myo', 'cluster'],
}))

const base: BlockData = {
  id: 'b1',
  slot_id: 's1',
  position: 0,
  role: 'working',
  technique: 'none',
  tut_eccentric_s: null,
  tut_bottom_pause_s: null,
  tut_concentric_s: null,
  tut_top_pause_s: null,
  rest_s: null,
  prep_s: null,
  ref_block_id: null,
}

function setup(block: Partial<BlockData> = {}) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <BlockDetails
        coachId="c1"
        mesocycleId="m1"
        block={{ ...base, ...block }}
        siblings={[{ id: 'x', label: 'Top set 1' }]}
      />
    </QueryClientProvider>,
  )
}
beforeEach(() => updateBlock.mockClear())

describe('BlockDetails', () => {
  it('ha le sezioni in chiaro, con unità e frase di riepilogo', () => {
    setup({ tut_eccentric_s: 3, tut_bottom_pause_s: 1, tut_concentric_s: 1, tut_top_pause_s: 0, rest_s: 90 })
    for (const title of [
      'Tipo di lavoro',
      'Tempo di esecuzione (TUT)',
      'Recuperi',
      'Progressione automatica',
    ])
      expect(screen.getByRole('heading', { name: title })).toBeInTheDocument()
    expect(screen.getByText(/^3-1-1-0: 3 s in discesa.*5 s a ripetizione\.$/)).toBeInTheDocument()
    expect(screen.getByText('Recupero 1 min 30 s.')).toBeInTheDocument()
  })

  it('il tipo di lavoro si sceglie e ogni scelta ha la sua descrizione', async () => {
    setup()
    expect(screen.getByRole('radio', { name: 'Lavoro' })).toBeChecked()
    expect(screen.getByText('Le serie normali dell’esercizio.')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('radio', { name: 'Top set' }))
    expect(updateBlock).toHaveBeenCalledWith('m1', 'b1', { role: 'top' })
  })

  it('«Calcola il carico da» compare solo per il back-off', () => {
    setup()
    expect(screen.queryByLabelText('Calcola il carico da')).not.toBeInTheDocument()
  })
  it('back-off: sceglie la serie di riferimento', async () => {
    setup({ role: 'backoff' })
    await userEvent.selectOptions(screen.getByLabelText('Calcola il carico da'), 'x')
    expect(updateBlock).toHaveBeenCalledWith('m1', 'b1', { ref_block_id: 'x' })
  })

  it('una scelta rapida scrive le quattro fasi insieme', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Controllato 3-0-1-0' }))
    expect(updateBlock).toHaveBeenCalledWith('m1', 'b1', {
      tut_eccentric_s: 3,
      tut_bottom_pause_s: 0,
      tut_concentric_s: 1,
      tut_top_pause_s: 0,
    })
  })

  it('togliere il tempo svuota le quattro fasi', async () => {
    setup({ tut_eccentric_s: 3 })
    await userEvent.click(screen.getByRole('button', { name: 'Togli il tempo' }))
    expect(updateBlock).toHaveBeenCalledWith('m1', 'b1', {
      tut_eccentric_s: null,
      tut_bottom_pause_s: null,
      tut_concentric_s: null,
      tut_top_pause_s: null,
    })
  })

  it('recupero: scelta rapida, e di nuovo clic la toglie', async () => {
    setup()
    await userEvent.click(screen.getByRole('radio', { name: '2 min' }))
    expect(updateBlock).toHaveBeenLastCalledWith('m1', 'b1', { rest_s: 120 })
  })
  it('recupero già scelto: il clic lo toglie', async () => {
    setup({ rest_s: 120 })
    await userEvent.click(screen.getByRole('radio', { name: '2 min' }))
    expect(updateBlock).toHaveBeenLastCalledWith('m1', 'b1', { rest_s: null })
  })
})
