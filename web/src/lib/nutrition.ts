import { queryOptions } from '@tanstack/react-query'
import { z } from 'zod'
import { messages } from './messages'
import { supabase } from './supabase'

const e = messages.app.nutrition.errors

/** Versione del testo della dichiarazione che il coach accetta: si salva sul piano e va cambiata quando il testo cambia. */
export const DECLARATION_VERSION = '2026-10-16'

export type MacroTargets = {
  kcal: number
  protein_g: number
  carbs_g: number
  fat_g: number
  fiber_g: number | null
}

export type NutritionPlan = {
  id: string
  /** Vale da questo giorno finché non ne arriva uno più recente. */
  validFrom: string
  tolerancePct: number
  declaredAt: string
  targets: MacroTargets
}

/** Oggi, nel fuso di chi guarda, come `YYYY-MM-DD` (non UTC: a mezzanotte il giorno cambia per lui). */
export function todayIso(now = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
}

export function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T12:00:00`)
  d.setDate(d.getDate() + days)
  return todayIso(d)
}

/** Piani dell'atleta, il più recente per primo. Li legge il coach collegato e l'atleta (RLS). */
export const nutritionPlansQuery = (athleteId: string) =>
  queryOptions({
    queryKey: ['nutrition-plans', athleteId],
    queryFn: async (): Promise<NutritionPlan[]> => {
      const { data, error } = await supabase
        .from('nutrition_plans')
        .select(
          'id, valid_from, tolerance_pct, declared_at, nutrition_plan_days(kcal, protein_g, carbs_g, fat_g, fiber_g)',
        )
        .eq('athlete_id', athleteId)
        .eq('kind', 'macros')
        .is('deleted_at', null)
        .order('valid_from', { ascending: false })
      if (error) throw error
      return data.flatMap((p) => {
        const day = p.nutrition_plan_days[0]
        return day
          ? [
              {
                id: p.id,
                validFrom: p.valid_from,
                tolerancePct: p.tolerance_pct,
                declaredAt: p.declared_at,
                targets: {
                  kcal: day.kcal,
                  protein_g: day.protein_g,
                  carbs_g: day.carbs_g,
                  fat_g: day.fat_g,
                  fiber_g: day.fiber_g,
                },
              },
            ]
          : []
      })
    },
  })

/** Il piano in vigore un certo giorno: il più recente tra quelli già iniziati. `plans` è ordinato dal più recente. */
export function planInForce(plans: readonly NutritionPlan[], day: string): NutritionPlan | null {
  return plans.find((p) => p.validFrom <= day) ?? null
}

// --- Il modulo degli obiettivi -------------------------------------------------------------------------------------

// Un campo vuoto è un errore (non vale 0).
const whole = (min: number, max: number, message: string) =>
  z
    .string(message)
    .trim()
    .min(1, message)
    .transform(Number)
    .pipe(z.number(message).int(message).min(min, message).max(max, message))

export const macroFormSchema = z.object({
  kcal: whole(500, 15000, e.kcal),
  protein_g: whole(0, 1000, e.protein),
  carbs_g: whole(0, 2000, e.carbs),
  fat_g: whole(0, 1000, e.fat),
  // Facoltativo: vuoto = non indicato.
  fiber_g: z
    .string()
    .trim()
    .transform((v) => (v === '' ? null : Number(v)))
    .pipe(z.number(e.fiber).int(e.fiber).min(0, e.fiber).max(300, e.fiber).nullable()),
  tolerance_pct: whole(0, 50, e.tolerance),
  valid_from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, e.validFrom),
  // La casella spuntata arriva come 'on'; non spuntata non arriva.
  declaration: z.literal('on', e.declaration),
})
export type MacroForm = z.infer<typeof macroFormSchema>

/** Calorie che escono dai macro (4 kcal/g proteine e carboidrati, 9 kcal/g grassi). */
export const kcalFromMacros = (v: Pick<MacroTargets, 'protein_g' | 'carbs_g' | 'fat_g'>) =>
  4 * v.protein_g + 4 * v.carbs_g + 9 * v.fat_g

/** Le calorie scritte e quelle dei macro differiscono di oltre il 10%: probabilmente un numero è sbagliato (si avvisa, non si blocca). */
export function macroMismatch(v: MacroTargets): boolean {
  return v.kcal > 0 && Math.abs(v.kcal - kcalFromMacros(v)) / v.kcal > 0.1
}

/**
 * Scrive gli obiettivi: un piano nuovo dal giorno scelto, oppure aggiorna quello che inizia già quel giorno.
 * La dichiarazione (data e versione del testo) si salva a ogni scrittura.
 */
export async function saveNutritionPlan(
  coachId: string,
  athleteId: string,
  values: MacroForm,
): Promise<void> {
  const { data: existing, error: findError } = await supabase
    .from('nutrition_plans')
    .select('id')
    .eq('athlete_id', athleteId)
    .eq('kind', 'macros')
    .eq('valid_from', values.valid_from)
    .is('deleted_at', null)
    .maybeSingle()
  if (findError) throw findError

  const plan = {
    tolerance_pct: values.tolerance_pct,
    declared_at: new Date().toISOString(),
    declaration_version: DECLARATION_VERSION,
  }
  let planId = existing?.id
  if (planId) {
    const { error } = await supabase.from('nutrition_plans').update(plan).eq('id', planId)
    if (error) throw error
  } else {
    const { data, error } = await supabase
      .from('nutrition_plans')
      .insert({
        ...plan,
        athlete_id: athleteId,
        author_id: coachId,
        kind: 'macros',
        valid_from: values.valid_from,
      })
      .select('id')
      .single()
    if (error) throw error
    planId = data.id
  }
  const { error } = await supabase.from('nutrition_plan_days').upsert(
    {
      plan_id: planId,
      day_type: 'all',
      kcal: values.kcal,
      protein_g: values.protein_g,
      carbs_g: values.carbs_g,
      fat_g: values.fat_g,
      fiber_g: values.fiber_g,
    },
    { onConflict: 'plan_id,day_type' },
  )
  if (error) throw error
}

// --- L'aderenza che l'atleta registra ---------------------------------------------------------------------------

export type DayStatus = 'respected' | 'not_respected' | null
export type DaySource = 'confirm' | 'healthkit' | 'manual' | null

export type OverviewDay = {
  day: string
  /** null = giorno non registrato (non conta come non rispettato). */
  status: DayStatus
  source: DaySource
  intake: { kcal: number | null; protein_g: number | null; carbs_g: number | null; fat_g: number | null }
  target: { kcal: number; protein_g: number; carbs_g: number; fat_g: number } | null
  tolerancePct: number | null
}

/** Un giorno per riga, con l'obiettivo di quel giorno e quello che l'atleta ha registrato (`nutrition_overview`). */
export const nutritionOverviewQuery = (athleteId: string, from: string, to: string) =>
  queryOptions({
    queryKey: ['nutrition-overview', athleteId, from, to],
    queryFn: async (): Promise<OverviewDay[]> => {
      const { data, error } = await supabase.rpc('nutrition_overview', {
        p_athlete_id: athleteId,
        p_from: from,
        p_to: to,
      })
      if (error) throw error
      return data.map((r) => ({
        day: r.day,
        status: r.status,
        source: r.source,
        intake: { kcal: r.kcal, protein_g: r.protein_g, carbs_g: r.carbs_g, fat_g: r.fat_g },
        target:
          r.target_kcal !== null
            ? {
                kcal: r.target_kcal,
                protein_g: r.target_protein_g!,
                carbs_g: r.target_carbs_g!,
                fat_g: r.target_fat_g!,
              }
            : null,
        tolerancePct: r.tolerance_pct,
      }))
    },
  })

/** Scarto in % rispetto all'obiettivo (+12 = 12% sopra); null se manca uno dei due o l'obiettivo è 0. */
export function deviationPct(actual: number | null, target: number | null | undefined): number | null {
  if (actual === null || !target) return null
  return Math.round(((actual - target) / target) * 100)
}

export type AdherenceSummary = { respected: number; notRespected: number; unregistered: number }

/** Quanti giorni rispettati, non rispettati e non registrati: i non registrati non si contano mai come non rispettati. */
export function adherenceSummary(days: readonly Pick<OverviewDay, 'status'>[]): AdherenceSummary {
  const out = { respected: 0, notRespected: 0, unregistered: 0 }
  for (const d of days) {
    if (d.status === 'respected') out.respected++
    else if (d.status === 'not_respected') out.notRespected++
    else out.unregistered++
  }
  return out
}
