import { describe, expect, it } from 'vitest'
import { buildRule, progressionSchema, ruleToInput } from './progressionRule'

const roundTrip = (rule: Record<string, unknown>) => {
  const parsed = progressionSchema.safeParse(ruleToInput(rule as never))
  return parsed.success ? buildRule(parsed.data) : parsed.error
}

describe('ruleToInput', () => {
  it('una regola completa torna identica dopo il modulo', () => {
    const rule = {
      sets: { start: 3, step: 1, max: 5 },
      reps_min: { start: 8 },
      reps_max: { start: 10 },
      method: 'BUF',
      intensity: { start: 3, step: -1, min: 0 },
      from_week: 2,
      to_week: 6,
    }
    expect(roundTrip(rule)).toEqual(rule)
  })
  it('solo le serie', () => expect(roundTrip({ sets: { start: 4 } })).toEqual({ sets: { start: 4 } }))
  it('decimali e un solo numero di ripetizioni', () => {
    const rule = {
      sets: { start: 3 },
      reps_min: { start: 12 },
      reps_max: { start: 12 },
      method: 'LOAD',
      intensity: { start: 62.5, step: 2.5 },
    }
    expect(roundTrip(rule)).toEqual(rule)
  })
  it('scrive i numeri come testo nei campi', () => {
    expect(
      ruleToInput({ sets: { start: 3, step: 0.5 }, method: 'RPE', intensity: { start: 7 } }),
    ).toMatchObject({
      setsStart: '3',
      setsStep: '0.5',
      method: 'RPE',
      intStart: '7',
      intStep: '',
    })
  })
  it('un valore che non è una regola dà campi vuoti, senza errori', () => {
    expect(ruleToInput(null).setsStart).toBe('')
    expect(ruleToInput([1, 2]).setsStart).toBe('')
    expect(ruleToInput('x').method).toBe('')
  })
})
