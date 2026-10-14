import { describe, expect, it } from 'vitest'
import { daysSince, initials, summarizeWorkouts } from './athletes'

const now = new Date(2026, 9, 14, 18, 0)

describe('initials', () => {
  it('nome e cognome', () => expect(initials('Giuseppe Scappaticci')).toBe('GS'))
  it('una sola parola', () => expect(initials('giuseppe')).toBe('G'))
  it('vuoto', () => expect(initials('')).toBe('?'))
})

describe('daysSince', () => {
  it('stesso giorno a orari diversi', () =>
    expect(daysSince(new Date(2026, 9, 14, 1).toISOString(), now)).toBe(0))
  it('ieri', () => expect(daysSince(new Date(2026, 9, 13, 23).toISOString(), now)).toBe(1))
})

describe('summarizeWorkouts', () => {
  it('nessuna seduta', () =>
    expect(summarizeWorkouts([], now)).toEqual({ lastWorkoutAt: null, workoutsLast7Days: 0 }))
  it('conta solo gli ultimi 7 giorni, oggi incluso', () => {
    const t = (d: number) => new Date(2026, 9, 14 - d, 10).toISOString()
    const r = summarizeWorkouts([t(7), t(6), t(0), t(2)], now)
    expect(r.workoutsLast7Days).toBe(3)
    expect(r.lastWorkoutAt).toBe(t(0))
  })
})
