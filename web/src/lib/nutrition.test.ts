import { describe, expect, it, vi } from 'vitest'

vi.mock('./supabase', () => ({ supabase: {} }))

import {
  addDays,
  adherenceSummary,
  deviationPct,
  kcalFromMacros,
  macroFormSchema,
  macroMismatch,
  planInForce,
  todayIso,
  type NutritionPlan,
} from './nutrition'

const valid = {
  kcal: '2500',
  protein_g: '180',
  carbs_g: '280',
  fat_g: '70',
  fiber_g: '30',
  tolerance_pct: '10',
  valid_from: '2026-10-16',
  declaration: 'on',
}

describe('macroFormSchema', () => {
  it('accetta un modulo completo e converte i numeri', () => {
    const parsed = macroFormSchema.parse(valid)
    expect(parsed).toMatchObject({
      kcal: 2500,
      protein_g: 180,
      carbs_g: 280,
      fat_g: 70,
      fiber_g: 30,
      tolerance_pct: 10,
    })
  })
  it('le fibre sono facoltative: vuoto vale «non indicato»', () => {
    expect(macroFormSchema.parse({ ...valid, fiber_g: '' }).fiber_g).toBeNull()
  })
  it('rifiuta numeri fuori misura o non interi', () => {
    for (const bad of [
      { kcal: '100' },
      { kcal: '2500.5' },
      { protein_g: '-1' },
      { fat_g: 'molti' },
      { tolerance_pct: '80' },
    ]) {
      expect(macroFormSchema.safeParse({ ...valid, ...bad }).success).toBe(false)
    }
  })
  it('senza la dichiarazione non si salva', () => {
    const { declaration: _declaration, ...withoutDeclaration } = valid
    const result = macroFormSchema.safeParse(withoutDeclaration)
    expect(result.error?.issues.some((i) => i.path[0] === 'declaration')).toBe(true)
  })
  it('la data di inizio deve essere una data', () => {
    expect(macroFormSchema.safeParse({ ...valid, valid_from: '' }).success).toBe(false)
  })
})

describe('calorie dai macro', () => {
  it('4 kcal per grammo di proteine e carboidrati, 9 per i grassi', () => {
    expect(kcalFromMacros({ protein_g: 180, carbs_g: 280, fat_g: 70 })).toBe(2470)
  })
  it('avvisa solo se le calorie scritte si discostano di oltre il 10%', () => {
    const base = { kcal: 2500, protein_g: 180, carbs_g: 280, fat_g: 70, fiber_g: null }
    expect(macroMismatch(base)).toBe(false)
    expect(macroMismatch({ ...base, kcal: 3200 })).toBe(true)
    expect(macroMismatch({ ...base, kcal: 2000 })).toBe(true)
  })
})

describe('piano in vigore', () => {
  const plan = (id: string, validFrom: string): NutritionPlan => ({
    id,
    validFrom,
    tolerancePct: 10,
    declaredAt: '2026-10-01T10:00:00Z',
    targets: { kcal: 2000, protein_g: 150, carbs_g: 200, fat_g: 60, fiber_g: null },
  })
  const plans = [plan('c', '2026-11-01'), plan('b', '2026-10-11'), plan('a', '2026-10-01')]
  it('vale il più recente tra quelli già iniziati', () => {
    expect(planInForce(plans, '2026-10-10')?.id).toBe('a')
    expect(planInForce(plans, '2026-10-11')?.id).toBe('b')
    expect(planInForce(plans, '2026-12-01')?.id).toBe('c')
  })
  it('prima del primo piano non c’è un obiettivo', () => {
    expect(planInForce(plans, '2026-09-30')).toBeNull()
    expect(planInForce([], '2026-10-10')).toBeNull()
  })
})

describe('date', () => {
  it('oggi nel fuso locale, a due cifre', () => {
    expect(todayIso(new Date(2026, 0, 5, 23, 30))).toBe('2026-01-05')
  })
  it('somma e sottrae giorni attraverso il cambio di mese e di anno', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01')
    expect(addDays('2026-01-01', -1)).toBe('2025-12-31')
  })
})

describe('scarto e riepilogo', () => {
  it('scarto in percentuale, con segno; mancano i dati = niente', () => {
    expect(deviationPct(2750, 2500)).toBe(10)
    expect(deviationPct(2250, 2500)).toBe(-10)
    expect(deviationPct(null, 2500)).toBeNull()
    expect(deviationPct(2500, 0)).toBeNull()
    expect(deviationPct(2500, undefined)).toBeNull()
  })
  it('i giorni non registrati non contano mai come non rispettati', () => {
    expect(
      adherenceSummary([
        { status: 'respected' },
        { status: 'respected' },
        { status: 'not_respected' },
        { status: null },
        { status: null },
      ]),
    ).toEqual({ respected: 2, notRespected: 1, unregistered: 2 })
  })
})
