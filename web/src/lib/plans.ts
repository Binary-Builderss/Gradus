import { queryOptions } from '@tanstack/react-query'
import { z } from 'zod'
import type { Database } from './database.types'
import { messages } from './messages'
import { supabase } from './supabase'

export type Plan = Database['public']['Enums']['coach_plan']
/** Dal più piccolo al più grande: serve a sapere quali piani stanno sopra quello attuale. */
export const PLANS: readonly Plan[] = ['free', 'basic', 'advanced', 'custom']

/** Quanta libertà ha il marchio: 0 nessuna · 1 logo, nome e colore principale · 2 tavolozza completa · 3 anche PDF senza la dicitura Gradus. */
export type BrandingLevel = 0 | 1 | 2 | 3

export type PlanUsage = {
  plan: Plan
  athleteLimit: number
  athletes: number
  /** Personalizza e PDF col marchio, a livelli (vedi `BrandingLevel`). */
  brandingLevel: BrandingLevel
  /** Quanti template di mesociclo e quante progressioni ha già salvato. */
  mesocycleTemplates: number
  progressionPresets: number
  /** Fine del periodo pagato (null = senza scadenza). */
  renewsUntil: string | null
  /** Disdetto: resta attivo fino a `renewsUntil`, poi torna Gratuito. */
  cancelAtPeriodEnd: boolean
  /** C'è un abbonamento presso il servizio di pagamento (false = piano assegnato a mano). */
  hasSubscription: boolean
}

/** Personalizza è disponibile (dal piano basic in su). */
export const canCustomize = (usage: Pick<PlanUsage, 'brandingLevel'>) => usage.brandingLevel >= 1

/** Piano, tetto di atleti e atleti attuali: la regola sta nel database (`plan_usage`), il web la legge. */
export const planUsageQuery = (userId: string) =>
  queryOptions({
    queryKey: ['plan-usage', userId],
    queryFn: async (): Promise<PlanUsage> => {
      const { data, error } = await supabase.rpc('plan_usage')
      if (error) throw error
      const row = data[0]
      if (!row) throw new Error('plan_usage vuoto')
      return {
        plan: row.plan,
        athleteLimit: row.athlete_limit,
        athletes: row.athletes,
        brandingLevel: row.branding_level as BrandingLevel,
        mesocycleTemplates: row.mesocycle_templates,
        progressionPresets: row.progression_presets,
        renewsUntil: row.renews_until as string | null,
        cancelAtPeriodEnd: row.cancel_at_period_end,
        hasSubscription: row.has_subscription,
      }
    },
  })

/** Tetti di ogni livello (la regola sta nel database: `plan_limits`). */
export type PlanLimits = {
  athletes: number
  sessionTemplates: number
  mesocycleTemplates: number
  progressionPresets: number
  dietPlans: number
  dietSnapshots: number
  brandingLevel: BrandingLevel
}

/** Tetti di ogni livello, per la pagina dei piani. */
export const planLimitsQuery = () =>
  queryOptions({
    queryKey: ['plan-limits'],
    staleTime: 60 * 60_000,
    queryFn: async (): Promise<Record<Plan, PlanLimits>> => {
      const { data, error } = await supabase.rpc('plan_limits')
      if (error) throw error
      const limits = {} as Record<Plan, PlanLimits>
      for (const row of data)
        limits[row.plan] = {
          athletes: row.athlete_limit,
          sessionTemplates: row.session_templates,
          mesocycleTemplates: row.mesocycle_templates,
          progressionPresets: row.progression_presets,
          dietPlans: row.diet_plans,
          dietSnapshots: row.diet_snapshots,
          brandingLevel: row.branding_level as BrandingLevel,
        }
      return limits
    },
  })

/** Dal 80% del tetto in su conviene avvisare: restano pochi posti. */
export const nearLimit = (usage: Pick<PlanUsage, 'athleteLimit' | 'athletes'>) =>
  usage.athletes >= usage.athleteLimit * 0.8

export const atLimit = (usage: Pick<PlanUsage, 'athleteLimit' | 'athletes'>) =>
  usage.athletes >= usage.athleteLimit

/** Invito sotto la Guida: a chi è sul piano gratuito, o a chi sta finendo i posti. */
export function upgradeHint(usage: PlanUsage): { title: string; body: string } | null {
  const m = messages.app.plans
  const slots = nearLimit(usage) ? m.slotsLeft(usage.athletes, usage.athleteLimit) : null
  if (usage.plan === 'free') return { title: m.upsellTitle, body: slots ?? m.upsellBody }
  if (usage.plan === 'custom') return null // sopra non c'è altro: per più posti si scrive a noi
  if (slots) return { title: m.moreAthletes, body: slots }
  return null
}

const httpsUrl = z.url().refine((u) => u.startsWith('https://'))

/**
 * Indirizzo dove si acquista un piano a pagamento (per esempio un link di pagamento): variabile pubblica
 * `VITE_CHECKOUT_URL_BASIC`, `_ADVANCED` o `_CUSTOM`. Finché manca, o se non è un https valido, il pulsante resta
 * «Presto disponibile».
 */
export function checkoutUrl(plan: Plan, raw?: unknown): string | null {
  const value = raw ?? (import.meta.env as Record<string, unknown>)[`VITE_CHECKOUT_URL_${plan.toUpperCase()}`]
  const parsed = httpsUrl.safeParse(value)
  return parsed.success ? parsed.data : null
}

/**
 * Portale dove il cliente gestisce e disdice l'abbonamento (per esempio il portale clienti del servizio di
 * pagamento): variabile pubblica `VITE_BILLING_PORTAL_URL`. Senza, la disdetta risulta «presto disponibile».
 */
export function billingPortalUrl(raw: unknown = import.meta.env.VITE_BILLING_PORTAL_URL): string | null {
  const parsed = httpsUrl.safeParse(raw)
  return parsed.success ? parsed.data : null
}
