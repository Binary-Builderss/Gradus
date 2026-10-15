import { describe, expect, it } from 'vitest'
import {
  contrastProblems,
  contrastRatio,
  normalizeHex,
  overridesFrom,
  resolveColors,
  STANDARD_COLORS,
} from './brand'

describe('normalizeHex', () => {
  it('accetta #rrggbb, rrggbb e #rgb', () => {
    expect(normalizeHex('#0a7d4b')).toBe('#0A7D4B')
    expect(normalizeHex('0a7d4b')).toBe('#0A7D4B')
    expect(normalizeHex(' #fa0 ')).toBe('#FFAA00')
  })
  it('rifiuta il resto', () => {
    for (const t of ['', 'verde', '#12', '#12345', '#1234567', '#gggggg']) expect(normalizeHex(t)).toBeNull()
  })
})

describe('resolveColors / overridesFrom', () => {
  it('senza scelte usa lo standard', () => expect(resolveColors(null)).toEqual(STANDARD_COLORS))
  it('sopra lo standard mette le scelte valide e ignora le non valide', () => {
    const c = resolveColors({ primary: '#0a7d4b', border: 'boh' })
    expect(c.primary).toBe('#0A7D4B')
    expect(c.border).toBe(STANDARD_COLORS.border)
  })
  it('si salvano solo i colori cambiati', () => {
    const colors = {
      ...STANDARD_COLORS,
      primary: '#0A7D4B',
      background: STANDARD_COLORS.background.toLowerCase(),
    }
    expect(overridesFrom(colors)).toEqual({ primary: '#0A7D4B' })
  })
})

describe('contrasto', () => {
  it('bianco su nero è il massimo, uguale è 1', () => {
    expect(contrastRatio('#FFFFFF', '#000000')).toBeCloseTo(21, 0)
    expect(contrastRatio('#336699', '#336699')).toBeCloseTo(1)
  })
  it('lo standard si legge bene', () => expect(contrastProblems(STANDARD_COLORS)).toEqual([]))
  it('segnala testo e pulsante poco leggibili', () =>
    expect(
      contrastProblems({ ...STANDARD_COLORS, foreground: '#CCCCCC', on_primary: STANDARD_COLORS.primary }),
    ).toEqual(['text', 'button']))
})
