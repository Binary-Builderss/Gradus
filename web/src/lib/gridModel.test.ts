import { describe, expect, it } from 'vitest'
import type { CellValue } from './cellSyntax'
import {
  type BlockData,
  buildGridRows,
  copyForwardOps,
  normalizeRange,
  pasteOps,
  rangeToTsv,
  type WeekData,
  weekSetTotals,
} from './gridModel'

const cell = (sets: number, reps = 8): CellValue => ({
  sets,
  repsMin: reps,
  repsMax: reps,
  method: null,
  value: null,
  refPct: null,
})
const block = (id: string, slot_id: string, position: number): BlockData => ({
  id,
  slot_id,
  position,
  role: 'working',
  technique: 'none',
  tut_eccentric_s: null,
  tut_bottom_pause_s: null,
  tut_concentric_s: null,
  tut_top_pause_s: null,
  rest_s: null,
  prep_s: null,
  ref_block_id: null,
})
const week = (block_id: string, w: number, sets: number): WeekData => ({ block_id, week: w, ...cell(sets) })

const groups = [
  { id: 'g2', session_id: 's1', position: 1, kind: 'single' as const },
  { id: 'g1', session_id: 's1', position: 0, kind: 'superset' as const },
  { id: 'gx', session_id: 'altra', position: 0, kind: 'single' as const },
]
const slots = [
  { id: 'a', group_id: 'g1', position: 1, exercise_name: 'Curl' },
  { id: 'b', group_id: 'g1', position: 0, exercise_name: 'Pushdown' },
  { id: 'c', group_id: 'g2', position: 0, exercise_name: 'Panca' },
  { id: 'z', group_id: 'gx', position: 0, exercise_name: 'Altra seduta' },
]
const blocks = [block('b2', 'b', 1), block('b1', 'b', 0), block('c1', 'c', 0)]
const weeks = [week('b1', 1, 3), week('b1', 2, 4), week('c1', 1, 5)]

describe('buildGridRows', () => {
  const rows = buildGridRows('s1', groups, slots, blocks, weeks)
  it('ordina gruppo, esercizio, blocco e ignora le altre sedute', () =>
    expect(rows.map((r) => r.key)).toEqual(['b1', 'b2', 'slot-a', 'c1']))
  it('un esercizio senza blocchi è una riga senza blockId', () => expect(rows[2]!.blockId).toBeNull())
  it('collega le settimane al blocco', () => expect(rows[0]!.cells.get(2)?.sets).toBe(4))
})

describe('copyForwardOps', () => {
  const rows = buildGridRows('s1', groups, slots, blocks, weeks)
  it('copia sulle successive, salta bloccate e righe vuote', () => {
    const ops = copyForwardOps(rows, 1, 4, new Set([3]))
    expect(ops.filter((o) => o.blockId === 'b1').map((o) => o.week)).toEqual([2, 4])
    expect(ops.filter((o) => o.blockId === 'c1').map((o) => o.week)).toEqual([2, 4])
    expect(ops.some((o) => o.blockId === 'b2')).toBe(false)
  })
  it('ultima settimana: niente da copiare', () => expect(copyForwardOps(rows, 4, 4, new Set())).toEqual([]))
})

describe('rangeToTsv e pasteOps', () => {
  const rows = buildGridRows('s1', groups, slots, blocks, weeks)
  it('copia un intervallo', () =>
    expect(rangeToTsv(rows, normalizeRange({ r: 0, c: 1 }, { r: 3, c: 0 }))).toBe('3x8\t4x8\n\t\n\t\n5x8\t'))
  it('incolla da una cella, saltando righe senza blocco, settimane bloccate e fuori griglia', () => {
    const r = pasteOps(rows, { r: 1, c: 0 }, '2x10\t3x10\t4x10\n9x9\t3x8 BUF 2\t', 3, new Set([2]))
    // riga 1 = b2; riga 2 = slot-a (senza blocco); colonne: sett. 1, 2 (bloccata), 3
    expect(r.ops).toEqual([
      { blockId: 'b2', week: 1, value: expect.objectContaining({ sets: 2 }) },
      { blockId: 'b2', week: 3, value: expect.objectContaining({ sets: 4 }) },
    ])
    expect(r.skipped).toBe(4)
  })
  it('conta il testo non valido senza scriverlo', () => {
    const r = pasteOps(rows, { r: 0, c: 0 }, 'boh\t3x8', 4, new Set())
    expect(r.invalid).toBe(1)
    expect(r.ops).toHaveLength(1)
  })
  it('cella vuota incollata = cancella la prescrizione', () =>
    expect(pasteOps(rows, { r: 0, c: 0 }, '', 4, new Set()).ops).toEqual([
      { blockId: 'b1', week: 1, value: null },
    ]))
})

describe('weekSetTotals', () => {
  it("somma le serie di tutti i blocchi per settimana, 0 dove non c'è prescrizione", () => {
    const rows = buildGridRows('s1', groups, slots, blocks, weeks)
    expect(weekSetTotals(rows, 3)).toEqual([8, 4, 0])
  })
})
