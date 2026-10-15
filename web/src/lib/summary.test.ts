import { describe, expect, it, vi } from 'vitest'
vi.mock('./supabase', () => ({ supabase: {} }))

import {
  buildProgressTable,
  buildVolumeTable,
  formatChange,
  formatVolume,
  heatPercent,
  type ProgressRow,
  type VolumeRow,
} from './summary'

const row = (week: number, muscle: VolumeRow['muscle'], prescribed: number, executed = 0): VolumeRow => ({
  week,
  muscle,
  prescribed,
  executed,
})

describe('buildVolumeTable', () => {
  const rows = [row(1, 'chest', 5, 4), row(2, 'chest', 4), row(1, 'triceps', 1.5), row(9, 'lats', 8)]
  const table = buildVolumeTable(rows, 3)
  it('ordina dal muscolo più allenato e ignora le settimane fuori dal mesociclo', () =>
    expect(table.map((t) => t.muscle)).toEqual(['chest', 'triceps']))
  it('riempie le settimane mancanti a zero', () =>
    expect(table[0]!.weeks).toEqual([
      { prescribed: 5, executed: 4 },
      { prescribed: 4, executed: 0 },
      { prescribed: 0, executed: 0 },
    ]))
  it('somma il prescritto', () => expect(table[0]!.total).toBe(9))
  it('niente righe, niente tabella', () => expect(buildVolumeTable([], 3)).toEqual([]))
})

describe('heatPercent', () => {
  it('zero resta senza colore, il massimo è il più scuro', () => {
    expect(heatPercent(0, 10)).toBe(0)
    expect(heatPercent(10, 10)).toBe(50)
    expect(heatPercent(5, 10)).toBeGreaterThan(12)
    expect(heatPercent(5, 0)).toBe(0)
  })
})

describe('formatVolume', () => {
  it('virgola italiana e al massimo un decimale', () => {
    expect(formatVolume(4)).toBe('4')
    expect(formatVolume(4.5)).toBe('4,5')
    expect(formatVolume(1.25)).toBe('1,3')
  })
})

const prog = (week: number, over: Partial<ProgressRow> = {}): ProgressRow => ({
  exerciseId: 'e1',
  exerciseName: 'Panca',
  week,
  setsPrescribed: 3,
  setsDone: 3,
  topLoadKg: 80,
  topReps: 8,
  e1rm: 101.3,
  ...over,
})

describe('buildProgressTable', () => {
  it('ordina per nome e ignora le settimane fuori dal mesociclo', () => {
    const table = buildProgressTable(
      [prog(1, { exerciseId: 'e2', exerciseName: 'Rematore' }), prog(1), prog(7)],
      3,
    )
    expect(table.map((t) => t.name)).toEqual(['Panca', 'Rematore'])
    expect(table[0]!.weeks).toHaveLength(3)
  })
  it('calcola la variazione tra prima e ultima stima e la migliore', () => {
    const [panca] = buildProgressTable([prog(1), prog(2, { e1rm: 105 }), prog(3, { e1rm: 103 })], 4)
    expect(panca!.bestE1rm).toBe(105)
    expect(panca!.e1rmChange).toBeCloseTo(1.7)
  })
  it('con una sola settimana di dati non c’è variazione', () => {
    const [panca] = buildProgressTable(
      [prog(1), prog(2, { setsDone: 0, e1rm: null, topLoadKg: null, topReps: null })],
      3,
    )
    expect(panca!.e1rmChange).toBeNull()
    expect(panca!.bestE1rm).toBe(101.3)
  })
})

describe('formatChange', () => {
  it('segno esplicito e virgola italiana', () => {
    expect(formatChange(4.5)).toBe('+4,5')
    expect(formatChange(-2)).toBe('\u22122')
    expect(formatChange(0)).toBe('0')
    expect(formatChange(0.04)).toBe('0')
  })
})
