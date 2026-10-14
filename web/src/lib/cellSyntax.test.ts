import { describe, expect, it } from 'vitest'
import { formatCell, parseCell, parseTsv, toTsv, type CellValue } from './cellSyntax'

const ok = (text: string) => {
  const r = parseCell(text)
  if (!r.ok) throw new Error(`non valido: ${text}`)
  return r.value
}

describe('parseCell', () => {
  it('vuoto = nessuna prescrizione', () => expect(ok('  ')).toBeNull())
  it('serie e range di ripetizioni', () =>
    expect(ok('3x8-10')).toEqual({
      sets: 3,
      repsMin: 8,
      repsMax: 10,
      method: null,
      value: null,
      refPct: null,
    }))
  it('ripetizioni fisse e × tipografica', () =>
    expect(ok('4×6')).toMatchObject({ sets: 4, repsMin: 6, repsMax: 6 }))
  it('solo serie', () => expect(ok('2')).toMatchObject({ sets: 2, repsMin: null, repsMax: null }))
  it('metodi di sforzo', () => {
    expect(ok('3x8 BUF 2')).toMatchObject({ method: 'BUF', value: 2 })
    expect(ok('3x8 rpe8')).toMatchObject({ method: 'RPE', value: 8 })
    expect(ok('1x5 RM 5')).toMatchObject({ method: 'RM', value: 5 })
  })
  it('percentuale del massimale e carico con virgola', () => {
    expect(ok('5x5 80%1RM')).toMatchObject({ method: 'PCT_1RM', value: 80 })
    expect(ok('3x8 62,5kg')).toMatchObject({ method: 'LOAD', value: 62.5 })
  })
  it('back-off legato: percentuale del blocco di riferimento, anche con un metodo', () => {
    expect(ok('2x8 85%ref')).toMatchObject({ method: null, refPct: 85 })
    expect(ok('2x8 BUF 1 90%ref')).toMatchObject({ method: 'BUF', value: 1, refPct: 90 })
  })
  it('rifiuta input malformati', () => {
    for (const bad of [
      'x8',
      'abc',
      '3x10-8',
      '3x8 BUF',
      '3x8 BUF 2 RPE 8',
      '3x8 80%',
      '3x8 85%ref 90%ref',
      '3x8 boh',
      '3x8 20000kg',
    ])
      expect(parseCell(bad).ok, bad).toBe(false)
  })
})

describe('formatCell', () => {
  it('cella vuota', () => expect(formatCell(null)).toBe(''))
  it('ripetibile: parse(format(x)) = x', () => {
    for (const text of [
      '3x8-10 BUF 2',
      '4x6 RPE 8',
      '5x5 80%1RM',
      '3x8 62,5kg',
      '2x8 BUF 1 90%ref',
      '2',
      '3x12',
    ]) {
      const cell = ok(text) as CellValue
      expect(formatCell(cell)).toBe(text)
      expect(ok(formatCell(cell))).toEqual(cell)
    }
  })
})

describe('tsv', () => {
  it('andata e ritorno', () => {
    const m = [
      ['3x8', '3x8 BUF 2'],
      ['', '4x6'],
    ]
    expect(parseTsv(toTsv(m))).toEqual(m)
  })
  it('gestisce CRLF e a capo finale (Excel / Fogli Google)', () =>
    expect(parseTsv('a\tb\r\nc\td\r\n')).toEqual([
      ['a', 'b'],
      ['c', 'd'],
    ]))
})
