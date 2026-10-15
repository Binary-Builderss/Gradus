import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { CellValue } from '@/lib/cellFields'
import type { GridRow } from '@/lib/gridModel'
import { SessionGrid } from './SessionGrid'

const { writeCells } = vi.hoisted(() => ({ writeCells: vi.fn(async () => {}) }))
vi.mock('@/lib/blocks', () => ({
  writeCells,
  addBlock: vi.fn(),
  updateBlock: vi.fn(),
  deleteBlock: vi.fn(),
  ROLES: ['warmup', 'top', 'backoff', 'working'],
  TECHNIQUES: ['none', 'drop', 'rest_pause', 'myo', 'cluster'],
}))

const cell = (sets: number): CellValue => ({
  sets,
  repsMin: 8,
  repsMax: 8,
  method: null,
  value: null,
  refPct: null,
})
const block = (id: string) => ({
  id,
  slot_id: id,
  position: 0,
  role: 'working' as const,
  technique: 'none' as const,
  tut_eccentric_s: null,
  tut_bottom_pause_s: null,
  tut_concentric_s: null,
  tut_top_pause_s: null,
  rest_s: null,
  prep_s: null,
  ref_block_id: null,
})
const row = (id: string, name: string, cells: [number, CellValue][]): GridRow => ({
  key: id,
  blockId: id,
  slotId: id,
  exerciseName: name,
  groupKind: 'single',
  block: block(id),
  cells: new Map(cells),
})

const rows = [row('b1', 'Panca', [[1, cell(3)]]), row('b2', 'Curl', [])]

function setup(locked: number[] = []) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <SessionGrid
        mesocycleId="m1"
        rows={rows}
        totalWeeks={3}
        deloadWeeks={[3]}
        lockedWeeks={new Set(locked)}
      />
    </QueryClientProvider>,
  )
  return (name: string, week: number, field = 'serie') =>
    screen.getByLabelText(`${name}, settimana ${week}, ${field}`) as HTMLInputElement
}

beforeEach(() => writeCells.mockClear())

describe('SessionGrid', () => {
  it('mostra le prescrizioni esistenti, un campo ciascuna', () => {
    const at = setup()
    expect(at('Panca', 1).value).toBe('3')
    expect(at('Panca', 1, 'ripetizioni').value).toBe('8')
    expect(at('Panca', 1, 'sforzo').value).toBe('')
    expect(at('Curl', 1).value).toBe('')
  })

  it('le serie creano la settimana e si salvano alla perdita del focus', async () => {
    const at = setup()
    await userEvent.type(at('Curl', 2), '4')
    await userEvent.tab()
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(1))
    expect(writeCells).toHaveBeenCalledWith('m1', [
      {
        blockId: 'b2',
        week: 2,
        value: { sets: 4, repsMin: null, repsMax: null, method: null, value: null, refPct: null },
      },
    ])
  })

  it('ripetizioni e sforzo si scrivono nei loro campi, con la misura della riga', async () => {
    const at = setup()
    await userEvent.type(at('Panca', 1, 'ripetizioni'), '{Control>}a{/Control}8-10')
    await userEvent.tab()
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(1))
    expect(writeCells).toHaveBeenLastCalledWith('m1', [
      expect.objectContaining({
        blockId: 'b1',
        week: 1,
        value: expect.objectContaining({ repsMin: 8, repsMax: 10 }),
      }),
    ])
    await userEvent.type(at('Panca', 1, 'sforzo'), '2')
    await userEvent.tab()
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(2))
    expect(writeCells).toHaveBeenLastCalledWith('m1', [
      expect.objectContaining({ week: 1, value: expect.objectContaining({ method: 'BUF', value: 2 }) }),
    ])
  })

  it('valore non valido: segnala e non salva', async () => {
    const at = setup()
    await userEvent.type(at('Curl', 1), 'boh')
    await userEvent.tab()
    expect(at('Curl', 1)).toHaveAttribute('aria-invalid', 'true')
    expect(writeCells).not.toHaveBeenCalled()
  })

  it('ripetizioni prima delle serie: segnala', async () => {
    const at = setup()
    await userEvent.type(at('Curl', 1, 'ripetizioni'), '8')
    await userEvent.tab()
    expect(at('Curl', 1, 'ripetizioni')).toHaveAttribute('aria-invalid', 'true')
    expect(writeCells).not.toHaveBeenCalled()
  })

  it('cancellare le serie elimina la prescrizione', async () => {
    const at = setup()
    await userEvent.clear(at('Panca', 1))
    await userEvent.tab()
    await waitFor(() =>
      expect(writeCells).toHaveBeenCalledWith('m1', [{ blockId: 'b1', week: 1, value: null }]),
    )
  })

  it('cambiare la misura riscrive lo sforzo già inserito', async () => {
    setup()
    await userEvent.selectOptions(screen.getByLabelText('Come misuri lo sforzo: Panca'), 'LOAD')
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(1))
    expect(writeCells).toHaveBeenCalledWith('m1', [
      { blockId: 'b1', week: 1, value: expect.objectContaining({ sets: 3, method: null }) },
    ])
  })

  it('frecce giù/su e Invio spostano il focus tra le righe', async () => {
    const at = setup()
    act(() => at('Panca', 2).focus())
    await userEvent.keyboard('{ArrowDown}')
    expect(at('Curl', 2)).toHaveFocus()
    await userEvent.keyboard('{ArrowUp}')
    expect(at('Panca', 2)).toHaveFocus()
    await userEvent.keyboard('{Enter}')
    expect(at('Curl', 2)).toHaveFocus()
  })

  it('freccia destra passa al campo accanto solo a fine testo, anche nella settimana dopo', async () => {
    const at = setup()
    act(() => at('Panca', 1).focus())
    at('Panca', 1).setSelectionRange(0, 0)
    await userEvent.keyboard('{ArrowRight}')
    expect(at('Panca', 1)).toHaveFocus() // caret all'inizio: la freccia sposta il cursore nel testo
    at('Panca', 1).setSelectionRange(1, 1)
    await userEvent.keyboard('{ArrowRight}')
    expect(at('Panca', 1, 'ripetizioni')).toHaveFocus()
    act(() => at('Panca', 1, 'sforzo').focus())
    await userEvent.keyboard('{ArrowRight}')
    expect(at('Panca', 2)).toHaveFocus()
  })

  it('le settimane bloccate sono di sola lettura', () => {
    const at = setup([1])
    expect(at('Panca', 1)).toHaveAttribute('readonly')
    expect(at('Panca', 2)).not.toHaveAttribute('readonly')
  })

  it('incolla una tabella TSV a partire dal campo attivo, saltando le settimane bloccate', async () => {
    const at = setup([3])
    act(() => at('Panca', 2).focus())
    fireEvent.paste(at('Panca', 2), {
      clipboardData: { getData: () => '2\t10\t\t5\t5\t\t1\t1\n3\t8\t2' },
    })
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(1))
    const ops = (writeCells.mock.calls[0] as unknown[])[1] as { blockId: string; week: number }[]
    expect(ops.map((o) => `${o.blockId}:${o.week}`)).toEqual(['b1:2', 'b2:2'])
  })

  it('copia sulle successive per la settimana scelta', async () => {
    setup()
    await userEvent.click(screen.getByRole('button', { name: 'Copia la settimana 1 sulle successive' }))
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(1))
    const ops = (writeCells.mock.calls[0] as unknown[])[1] as { blockId: string; week: number }[]
    expect(ops.map((o) => `${o.blockId}:${o.week}`)).toEqual(['b1:2', 'b1:3'])
  })

  it('la barra sopra la griglia dice la prescrizione a parole', () => {
    const at = setup()
    expect(screen.getByText(/Clicca un campo e scrivi/)).toBeInTheDocument()
    act(() => at('Panca', 1).focus())
    expect(screen.getByText('Panca › Lavoro › Settimana 1')).toBeInTheDocument()
    expect(screen.getByText('3 serie da 8 ripetizioni')).toBeInTheDocument()
  })

  it('mostra le serie totali per settimana', () => {
    setup()
    const footer = screen.getByRole('row', { name: /Serie totali della seduta/ })
    expect(footer).toHaveTextContent('3')
  })
})
