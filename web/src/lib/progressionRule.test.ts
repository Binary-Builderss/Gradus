import { describe, expect, it } from 'vitest'
import { buildRule, progressionSchema } from './progressionRule'

const empty = {
  setsStart: '',
  setsStep: '',
  setsMax: '',
  repsMin: '',
  repsMax: '',
  method: '',
  intStart: '',
  intStep: '',
  intMin: '',
  fromWeek: '',
  toWeek: '',
}
const parse = (over: Record<string, string>) => progressionSchema.safeParse({ ...empty, ...over })

describe('progressionSchema + buildRule', () => {
  it('esempio del manuale: BUF da 3 a 0, +1 serie a settimana', () => {
    const r = parse({
      setsStart: '3',
      setsStep: '1',
      setsMax: '5',
      repsMin: '8',
      repsMax: '10',
      method: 'BUF',
      intStart: '3',
      intStep: '-1',
      intMin: '0',
    })
    expect(r.success).toBe(true)
    expect(buildRule(r.data!)).toEqual({
      sets: { start: 3, step: 1, max: 5 },
      reps_min: { start: 8 },
      reps_max: { start: 10 },
      method: 'BUF',
      intensity: { start: 3, step: -1, min: 0 },
    })
  })
  it('solo serie: nessun campo superfluo', () => {
    const r = parse({ setsStart: '4' })
    expect(buildRule(r.data!)).toEqual({ sets: { start: 4 } })
  })
  it('un solo estremo delle ripetizioni vale per entrambi; settimane e virgola decimale', () => {
    const r = parse({
      setsStart: '3',
      repsMin: '12',
      method: 'LOAD',
      intStart: '62,5',
      fromWeek: '2',
      toWeek: '5',
    })
    expect(buildRule(r.data!)).toMatchObject({
      reps_min: { start: 12 },
      reps_max: { start: 12 },
      intensity: { start: 62.5 },
      from_week: 2,
      to_week: 5,
    })
  })
  it('rifiuta: serie mancanti, ripetizioni invertite, metodo senza intensità e viceversa, intervallo invertito, testo', () => {
    expect(parse({}).success).toBe(false)
    expect(parse({ setsStart: '3', repsMin: '10', repsMax: '8' }).success).toBe(false)
    expect(parse({ setsStart: '3', method: 'BUF' }).success).toBe(false)
    expect(parse({ setsStart: '3', intStart: '2' }).success).toBe(false)
    expect(parse({ setsStart: '3', fromWeek: '5', toWeek: '2' }).success).toBe(false)
    expect(parse({ setsStart: 'tre' }).success).toBe(false)
    expect(parse({ setsStart: '2.5' }).success).toBe(false)
  })
})
