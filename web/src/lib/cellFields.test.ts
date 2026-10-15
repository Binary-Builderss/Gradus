import { describe, expect, it } from 'vitest'
import {
  type CellValue,
  type Field,
  type Measure,
  changeMeasure,
  describeCell,
  editField,
  fieldText,
  measureOf,
  parseTsv,
  toTsv,
} from './cellFields'

const cell = (over: Partial<CellValue> = {}): CellValue => ({
  sets: 3,
  repsMin: 8,
  repsMax: 8,
  method: null,
  value: null,
  refPct: null,
  ...over,
})
const edit = (c: CellValue | undefined, f: Field, t: string, m: Measure = 'BUF') => editField(c, f, t, m)

describe('fieldText', () => {
  it('scrive ogni campo come lo leggerebbe il coach', () => {
    const c = cell({ repsMin: 8, repsMax: 10, method: 'BUF', value: 2.5 })
    expect(fieldText(c, 'sets', 'BUF')).toBe('3')
    expect(fieldText(c, 'reps', 'BUF')).toBe('8-10')
    expect(fieldText(c, 'value', 'BUF')).toBe('2,5')
  })
  it('lo sforzo si vede solo nella misura della riga', () =>
    expect(fieldText(cell({ method: 'RPE', value: 8 }), 'value', 'BUF')).toBe(''))
  it('la percentuale del top set sta nel campo sforzo', () =>
    expect(fieldText(cell({ refPct: 85 }), 'value', 'REF')).toBe('85'))
  it('cella assente = vuoto', () => expect(fieldText(undefined, 'sets', 'BUF')).toBe(''))
})

describe('editField', () => {
  it('le serie creano la prescrizione', () =>
    expect(edit(undefined, 'sets', '4')).toEqual({ ok: true, cell: expect.objectContaining({ sets: 4 }) }))
  it('serie vuote = nessuna prescrizione', () =>
    expect(edit(cell(), 'sets', '')).toEqual({ ok: true, cell: null }))
  it('serie non valide', () => {
    for (const t of ['0', 'x', '3x8', '100', '-1']) expect(edit(cell(), 'sets', t)).toEqual({ ok: false })
  })
  it('ripetizioni singole e a intervallo', () => {
    expect(edit(cell(), 'reps', '6')).toEqual({ ok: true, cell: cell({ repsMin: 6, repsMax: 6 }) })
    expect(edit(cell(), 'reps', '8 - 10')).toEqual({ ok: true, cell: cell({ repsMin: 8, repsMax: 10 }) })
    expect(edit(cell(), 'reps', '10-8')).toEqual({ ok: false })
  })
  it('ripetizioni vuote le tolgono', () =>
    expect(edit(cell(), 'reps', '')).toEqual({ ok: true, cell: cell({ repsMin: null, repsMax: null }) }))
  it('ripetizioni e sforzo senza serie non si scrivono, ma vuoti sono ok', () => {
    expect(edit(undefined, 'reps', '8')).toEqual({ ok: false })
    expect(edit(undefined, 'value', '2')).toEqual({ ok: false })
    expect(edit(undefined, 'reps', '')).toEqual({ ok: true, cell: null })
  })
  it('lo sforzo prende la misura della riga, con la virgola', () => {
    expect(edit(cell(), 'value', '2,5', 'BUF')).toEqual({
      ok: true,
      cell: cell({ method: 'BUF', value: 2.5 }),
    })
    expect(edit(cell(), 'value', '60', 'LOAD')).toEqual({
      ok: true,
      cell: cell({ method: 'LOAD', value: 60 }),
    })
  })
  it('lo sforzo vuoto toglie metodo e valore insieme', () =>
    expect(edit(cell({ method: 'BUF', value: 2 }), 'value', '')).toEqual({ ok: true, cell: cell() }))
  it('la percentuale del top set va in ref_pct e lascia il resto', () =>
    expect(edit(cell({ method: 'BUF', value: 1 }), 'value', '85', 'REF')).toEqual({
      ok: true,
      cell: cell({ method: 'BUF', value: 1, refPct: 85 }),
    }))
  it('rifiuta valori fuori scala', () => {
    expect(edit(cell(), 'value', '11', 'RPE')).toEqual({ ok: false })
    expect(edit(cell(), 'value', 'due')).toEqual({ ok: false })
  })
})

describe('changeMeasure', () => {
  it('tiene il numero se sta nella nuova scala', () =>
    expect(changeMeasure(cell({ method: 'BUF', value: 2 }), 'BUF', 'RPE')).toEqual(
      cell({ method: 'RPE', value: 2 }),
    ))
  it('lo scarta se è fuori scala', () =>
    expect(changeMeasure(cell({ method: 'LOAD', value: 60 }), 'LOAD', 'BUF')).toEqual(cell()))
  it('da e verso la percentuale del top set', () => {
    expect(changeMeasure(cell({ method: 'BUF', value: 85 }), 'BUF', 'REF')).toEqual(cell({ refPct: 85 }))
    expect(changeMeasure(cell({ refPct: 85 }), 'REF', 'LOAD')).toEqual(cell({ method: 'LOAD', value: 85 }))
  })
})

describe('measureOf', () => {
  it('usa il metodo già scritto, poi la percentuale, poi BUF', () => {
    expect(measureOf([cell(), cell({ method: 'LOAD', value: 50 })])).toBe('LOAD')
    expect(measureOf([cell({ refPct: 80 })])).toBe('REF')
    expect(measureOf([])).toBe('BUF')
  })
})

describe('describeCell', () => {
  it('serie e ripetizioni', () => expect(describeCell(cell(), 'BUF')).toBe('3 serie da 8 ripetizioni'))
  it('con sforzo', () => {
    expect(describeCell(cell({ repsMin: 8, repsMax: 10, method: 'BUF', value: 2 }), 'BUF')).toBe(
      '3 serie da 8-10 ripetizioni, 2 ripetizioni in riserva',
    )
    expect(describeCell(cell({ method: 'BUF', value: 0 }), 'BUF')).toBe(
      '3 serie da 8 ripetizioni, a cedimento',
    )
    expect(describeCell(cell({ refPct: 85 }), 'REF')).toBe(
      '3 serie da 8 ripetizioni, 85% del carico del top set',
    )
  })
  it('solo serie', () => expect(describeCell(cell({ repsMin: null, repsMax: null }), 'BUF')).toBe('3 serie'))
})

describe('tsv', () => {
  it('andata e ritorno', () => {
    const m = [
      ['3', '8', '2'],
      ['', '4', '6'],
    ]
    expect(parseTsv(toTsv(m))).toEqual(m)
  })
  it('gestisce CRLF e a capo finale (Excel / Fogli Google)', () =>
    expect(parseTsv('a\tb\r\nc\td\r\n')).toEqual([
      ['a', 'b'],
      ['c', 'd'],
    ]))
})
