import { describe, expect, it } from 'vitest'
import { describeTempo, formatSeconds, NO_TEMPO, repSeconds, tempoNotation } from './tempo'

const t = (a: number | null, b: number | null, c: number | null, d: number | null) => ({
  tut_eccentric_s: a,
  tut_bottom_pause_s: b,
  tut_concentric_s: c,
  tut_top_pause_s: d,
})

describe('tempo', () => {
  it('notazione discesa-fermo-salita-fermo', () => {
    expect(tempoNotation(t(3, 1, 1, 0))).toBe('3-1-1-0')
    expect(tempoNotation(t(2, null, 1, null))).toBe('2-0-1-0')
    expect(tempoNotation(NO_TEMPO)).toBeNull()
  })
  it('durata di una ripetizione: le fasi vuote contano zero', () => {
    expect(repSeconds(t(3, 1, 1, 0))).toBe(5)
    expect(repSeconds(t(4, null, 2, null))).toBe(6)
    expect(repSeconds(NO_TEMPO)).toBe(0)
  })
  it('frase a parole', () => {
    expect(describeTempo(t(3, 1, 1, 0))).toBe(
      '3-1-1-0: 3 s in discesa, 1 s fermo in basso, 1 s in salita, 0 s fermo in alto. 5 s a ripetizione.',
    )
    expect(describeTempo(NO_TEMPO)).toMatch(/Nessun tempo/)
  })
  it('secondi leggibili', () => {
    expect(formatSeconds(45)).toBe('45 s')
    expect(formatSeconds(120)).toBe('2 min')
    expect(formatSeconds(90)).toBe('1 min 30 s')
  })
})
