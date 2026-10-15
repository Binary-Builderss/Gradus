import { describe, expect, it } from 'vitest'
import { kindAfterSlotCount, matchesSearch, muscleGroupOf, positionChanges } from './slotRules'

describe('kindAfterSlotCount', () => {
  it('un esercizio solo: sempre single', () => {
    expect(kindAfterSlotCount('giant', 1)).toBe('single')
    expect(kindAfterSlotCount('superset', 0)).toBe('single')
  })
  it('due o più: single diventa superset, gli altri restano', () => {
    expect(kindAfterSlotCount('single', 2)).toBe('superset')
    expect(kindAfterSlotCount('circuit', 4)).toBe('circuit')
  })
})

describe('positionChanges', () => {
  const current = [
    { id: 'a', position: 0 },
    { id: 'b', position: 1 },
    { id: 'c', position: 2 },
  ]
  it('ordine invariato: nessuna scrittura', () =>
    expect(positionChanges(['a', 'b', 'c'], current)).toEqual([]))
  it('scambio: solo le righe spostate', () =>
    expect(positionChanges(['a', 'c', 'b'], current)).toEqual([
      { id: 'c', position: 1 },
      { id: 'b', position: 2 },
    ]))
  it('rinumera posizioni con buchi', () =>
    expect(
      positionChanges(
        ['a', 'b'],
        [
          { id: 'a', position: 0 },
          { id: 'b', position: 5 },
        ],
      ),
    ).toEqual([{ id: 'b', position: 1 }]))
})

describe('matchesSearch', () => {
  it('ignora maiuscole e accenti', () => {
    expect(matchesSearch('Pressa orizzontale', 'PRESSA')).toBe(true)
    expect(matchesSearch('Curl bicipiti', 'bicipiti ')).toBe(true)
    expect(matchesSearch('Pec dèck', 'deck')).toBe(true)
    expect(matchesSearch('Squat', 'stacco')).toBe(false)
  })
})

describe('muscleGroupOf', () => {
  it('usa il muscolo con il peso maggiore', () => {
    expect(
      muscleGroupOf([
        { muscle: 'triceps', weight: 0.5 },
        { muscle: 'chest', weight: 1 },
      ]),
    ).toBe('chest')
    expect(muscleGroupOf([{ muscle: 'abductors', weight: 1 }])).toBe('legs')
  })
  it('senza muscoli non ha gruppo', () => expect(muscleGroupOf([])).toBeNull())
})
