import { describe, expect, it } from 'vitest'
import type { BlockData, WeekData } from './gridModel'
import { buildPdfModel, pdfFileName } from './pdfModel'

const block = (id: string, slot_id: string, position: number, over: Partial<BlockData> = {}): BlockData => ({
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
  ...over,
})
const wk = (block_id: string, week: number, over: Partial<WeekData> = {}): WeekData => ({
  block_id,
  week,
  sets: 3,
  repsMin: 8,
  repsMax: 10,
  method: 'BUF',
  value: 2,
  refPct: null,
  ...over,
})

const groups = [
  {
    id: 'g1',
    session_id: 's1',
    position: 0,
    kind: 'single' as const,
    rest_between_s: 0,
    rest_after_round_s: 0,
  },
  {
    id: 'g2',
    session_id: 's1',
    position: 1,
    kind: 'superset' as const,
    rest_between_s: 0,
    rest_after_round_s: 0,
  },
  {
    id: 'gx',
    session_id: 's2',
    position: 0,
    kind: 'single' as const,
    rest_between_s: 0,
    rest_after_round_s: 0,
  },
]
const slots = [
  { id: 'a', group_id: 'g1', position: 0, exercise_id: 'e1', exercise_name: 'Panca piana' },
  { id: 'b', group_id: 'g2', position: 0, exercise_id: 'e2', exercise_name: 'Curl' },
  { id: 'c', group_id: 'g2', position: 1, exercise_id: 'e3', exercise_name: 'Pushdown' },
  { id: 'z', group_id: 'gx', position: 0, exercise_id: 'e4', exercise_name: 'Squat' },
]
const blocks = [
  block('b1', 'a', 0, {
    role: 'top',
    rest_s: 150,
    tut_eccentric_s: 3,
    tut_bottom_pause_s: 1,
    tut_concentric_s: 1,
    tut_top_pause_s: 0,
  }),
  block('b2', 'a', 1, { role: 'backoff', technique: 'drop' }),
  block('b3', 'b', 0),
  block('b4', 'c', 0),
  block('b5', 'z', 0),
]
const weeks = [
  wk('b1', 1),
  wk('b1', 2, { sets: 4, repsMin: 6, repsMax: 6, method: 'LOAD', value: 80 }),
  wk('b2', 1, { method: null, value: null, refPct: 85 }),
  wk('b3', 1),
  wk('b4', 1, { repsMin: null, repsMax: null, method: null, value: null }),
]

const model = buildPdfModel({
  brandName: 'Studio Verde',
  athleteName: 'Giulia Rossi',
  mesocycle: { name: 'Blocco 1', start_date: '2026-10-19', weeks: 3, deload_weeks: [3] },
  sessions: [
    { id: 's1', name: 'Spinta' },
    { id: 's2', name: 'Gambe' },
  ],
  groups,
  slots,
  blocks,
  weeks,
  formatDate: (iso) => iso,
})

describe('buildPdfModel', () => {
  const [spinta, gambe] = model.sessions
  it('una tabella per seduta, ognuna con i propri esercizi', () => {
    expect(model.sessions.map((s) => s.name)).toEqual(['Spinta', 'Gambe'])
    expect(gambe!.rows.map((r) => r.name)).toEqual(['Squat'])
  })
  it('numera gli esercizi e nei superset aggiunge la lettera', () =>
    expect(spinta!.rows.map((r) => r.number)).toEqual(['1', '', '2A', '2B']))
  it('il secondo blocco dello stesso esercizio non ripete il nome', () =>
    expect(spinta!.rows.map((r) => r.name)).toEqual(['Panca piana', '', 'Curl', 'Pushdown']))
  it('scrive serie, ripetizioni e sforzo a parole', () => {
    expect(spinta!.rows[0]!.cells[0]).toEqual({ main: '3 × 8-10', sub: '2 in riserva' })
    expect(spinta!.rows[0]!.cells[1]).toEqual({ main: '4 × 6', sub: '80 kg' })
  })
  it('ogni settimana usa la propria misura anche se cambia nella riga', () =>
    expect([spinta!.rows[0]!.cells[0]!.sub, spinta!.rows[0]!.cells[1]!.sub]).toEqual([
      '2 in riserva',
      '80 kg',
    ]))
  it('il back-off mostra la percentuale del top set', () =>
    expect(spinta!.rows[1]!.cells[0]).toEqual({ main: '3 × 8-10', sub: '85% del top set' }))
  it('senza ripetizioni scrive solo le serie, senza prescrizione lascia vuoto', () => {
    expect(spinta!.rows[3]!.cells[0]).toEqual({ main: '3 serie', sub: '' })
    expect(spinta!.rows[0]!.cells[2]).toEqual({ main: '', sub: '' })
  })
  it('una colonna per settimana', () => expect(spinta!.rows[0]!.cells).toHaveLength(3))
  it('note: tipo di serie, tecnica, recupero e tempo', () => {
    expect(spinta!.rows[0]!.notes).toEqual(['Top set', 'recupero 150 s', 'tempo 3-1-1-0'])
    expect(spinta!.rows[1]!.notes).toEqual(['Back-off', 'Drop set'])
    expect(spinta!.rows[2]!.notes).toEqual([])
  })
  it('intestazione con atleta, mesociclo, inizio e durata', () =>
    expect(model.meta.map((x) => x.value)).toEqual(['Giulia Rossi', 'Blocco 1', '2026-10-19', '3 settimane']))
})

describe('pdfFileName', () => {
  it('toglie i caratteri non ammessi nei nomi file', () =>
    expect(pdfFileName('Blocco 1: forza/ipertrofia', 'Giulia')).toBe(
      'Blocco 1 forza ipertrofia - Giulia.pdf',
    ))
})
