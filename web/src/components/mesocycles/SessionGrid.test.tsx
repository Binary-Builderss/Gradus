import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { CellValue } from '@/lib/cellSyntax'
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
  return (name: string, week: number) =>
    screen.getByLabelText(`${name}, settimana ${week}`) as HTMLInputElement
}

beforeEach(() => writeCells.mockClear())

describe('SessionGrid', () => {
  it('mostra le prescrizioni esistenti', () => {
    const at = setup()
    expect(at('Panca', 1).value).toBe('3x8')
    expect(at('Curl', 1).value).toBe('')
  })

  it('salva alla perdita del focus con il formato compatto', async () => {
    const at = setup()
    await userEvent.type(at('Curl', 2), '4x6-8 RPE 8')
    await userEvent.tab()
    await waitFor(() => expect(writeCells).toHaveBeenCalledTimes(1))
    expect(writeCells).toHaveBeenCalledWith('m1', [
      {
        blockId: 'b2',
        week: 2,
        value: { sets: 4, repsMin: 6, repsMax: 8, method: 'RPE', value: 8, refPct: null },
      },
    ])
  })

  it('formato non valido: segnala e non salva', async () => {
    const at = setup()
    await userEvent.type(at('Curl', 1), 'boh')
    await userEvent.tab()
    expect(at('Curl', 1)).toHaveAttribute('aria-invalid', 'true')
    expect(writeCells).not.toHaveBeenCalled()
  })

  it('cancellare il testo elimina la prescrizione', async () => {
    const at = setup()
    await userEvent.clear(at('Panca', 1))
    await userEvent.tab()
    await waitFor(() =>
      expect(writeCells).toHaveBeenCalledWith('m1', [{ blockId: 'b1', week: 1, value: null }]),
    )
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

  it('freccia destra passa alla cella accanto solo a fine testo', async () => {
    const at = setup()
    act(() => at('Panca', 1).focus())
    at('Panca', 1).setSelectionRange(0, 0)
    await userEvent.keyboard('{ArrowRight}')
    expect(at('Panca', 1)).toHaveFocus() // caret all'inizio: la freccia sposta il cursore nel testo
    at('Panca', 1).setSelectionRange(3, 3)
    await userEvent.keyboard('{ArrowRight}')
    expect(at('Panca', 2)).toHaveFocus()
  })

  it('le settimane bloccate sono di sola lettura', () => {
    const at = setup([1])
    expect(at('Panca', 1)).toHaveAttribute('readonly')
    expect(at('Panca', 2)).not.toHaveAttribute('readonly')
  })

  it('incolla una tabella TSV a partire dalla cella attiva, saltando le bloccate', async () => {
    const at = setup([3])
    act(() => at('Panca', 2).focus())
    fireEvent.paste(at('Panca', 2), { clipboardData: { getData: () => '2x10\t5x5\n3x8 BUF 2\t3x8' } })
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

  it('la barra sopra la griglia dice quale cella stai modificando', () => {
    const at = setup()
    expect(screen.getByText('Seleziona una cella per modificarla.')).toBeInTheDocument()
    act(() => at('Panca', 1).focus())
    expect(screen.getByText('Panca › Lavoro › Settimana 1')).toBeInTheDocument()
  })

  it('mostra le serie totali per settimana', () => {
    setup()
    const footer = screen.getByRole('row', { name: /Serie totali della seduta/ })
    expect(footer).toHaveTextContent('3')
  })
})
