import { describe, expect, it } from 'vitest'
import { clampDeload, newMesocycleSchema, nextPosition, toggleDeload } from './mesocycleSchema'

describe('toggleDeload', () => {
  it('aggiunge in ordine e toglie', () => {
    expect(toggleDeload([4], 2, 6)).toEqual([2, 4])
    expect(toggleDeload([2, 4], 2, 6)).toEqual([4])
  })
  it('ignora settimane fuori dal mesociclo', () => {
    expect(toggleDeload([2], 7, 6)).toEqual([2])
    expect(toggleDeload([2], 0, 6)).toEqual([2])
  })
})

describe('clampDeload', () => {
  it('riducendo le settimane cadono gli scarichi oltre la durata, senza doppioni', () => {
    expect(clampDeload([6, 3, 3, 8], 6)).toEqual([3, 6])
    expect(clampDeload([6, 3], 4)).toEqual([3])
  })
})

describe('nextPosition', () => {
  it("lista vuota parte da 0, altrimenti dopo l'ultima", () => {
    expect(nextPosition([])).toBe(0)
    expect(nextPosition([{ position: 0 }, { position: 4 }])).toBe(5)
  })
})

describe('newMesocycleSchema', () => {
  const ok = { name: ' Ipertrofia 1 ', start_date: '2026-10-19', weeks: '8' }
  it('normalizza nome e settimane', () => {
    expect(newMesocycleSchema.parse(ok)).toEqual({ name: 'Ipertrofia 1', start_date: '2026-10-19', weeks: 8 })
  })
  it('rifiuta nome vuoto, data mancante, settimane fuori 1..52', () => {
    expect(newMesocycleSchema.safeParse({ ...ok, name: '  ' }).success).toBe(false)
    expect(newMesocycleSchema.safeParse({ ...ok, start_date: '' }).success).toBe(false)
    expect(newMesocycleSchema.safeParse({ ...ok, weeks: '0' }).success).toBe(false)
    expect(newMesocycleSchema.safeParse({ ...ok, weeks: '53' }).success).toBe(false)
    expect(newMesocycleSchema.safeParse({ ...ok, weeks: '' }).success).toBe(false)
  })
})
