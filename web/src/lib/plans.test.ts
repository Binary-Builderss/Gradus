import { describe, expect, it, vi } from 'vitest'

vi.mock('./supabase', () => ({ supabase: {} }))

import {
  atLimit,
  billingPortalUrl,
  canCustomize,
  checkoutUrl,
  nearLimit,
  upgradeHint,
  type PlanUsage,
} from './plans'

describe('checkoutUrl', () => {
  it('un https valido passa', () =>
    expect(checkoutUrl('advanced', 'https://buy.example.com/abc')).toBe('https://buy.example.com/abc'))
  it('assente o vuoto: nessun acquisto ancora', () => {
    expect(checkoutUrl('advanced', '')).toBeNull()
    expect(checkoutUrl('advanced', undefined)).toBeNull()
  })
  it('rifiuta http e schemi pericolosi', () => {
    expect(checkoutUrl('advanced', 'http://buy.example.com')).toBeNull()
    expect(checkoutUrl('advanced', 'javascript:alert(1)')).toBeNull()
  })
  it('legge la variabile del piano richiesto', () => {
    vi.stubEnv('VITE_CHECKOUT_URL_BASIC', 'https://buy.example.com/basic')
    expect(checkoutUrl('basic')).toBe('https://buy.example.com/basic')
    expect(checkoutUrl('custom')).toBeNull()
    vi.unstubAllEnvs()
  })
})

describe('tetto di atleti', () => {
  it('avvisa dall’80% in su e blocca al tetto', () => {
    expect(nearLimit({ athleteLimit: 20, athletes: 15 })).toBe(false)
    expect(nearLimit({ athleteLimit: 20, athletes: 16 })).toBe(true)
    expect(atLimit({ athleteLimit: 20, athletes: 19 })).toBe(false)
    expect(atLimit({ athleteLimit: 20, athletes: 20 })).toBe(true)
  })
})

const usage = (plan: PlanUsage['plan'], athletes: number, athleteLimit: number): PlanUsage => ({
  plan,
  athleteLimit,
  athletes,
  brandingLevel: plan === 'free' ? 0 : 1,
  mesocycleTemplates: 0,
  progressionPresets: 0,
  renewsUntil: null,
  cancelAtPeriodEnd: false,
  hasSubscription: false,
})

describe('canCustomize e upgradeHint', () => {
  it("Personalizza c'è dal livello 1", () => {
    expect(canCustomize({ brandingLevel: 0 })).toBe(false)
    expect(canCustomize({ brandingLevel: 1 })).toBe(true)
  })
  it('il piano Free invita sempre a passare a Basic; gli altri solo se i posti stanno finendo; Custom mai', () => {
    expect(upgradeHint(usage('free', 3, 20))?.title).toBe('Passa a Basic')
    expect(upgradeHint(usage('basic', 10, 50))).toBeNull()
    expect(upgradeHint(usage('basic', 45, 50))?.title).toBe('Più atleti')
    expect(upgradeHint(usage('custom', 490, 500))).toBeNull()
  })
})

describe('billingPortalUrl', () => {
  it('solo https; assente o altro = nessun portale', () => {
    expect(billingPortalUrl('https://billing.example.com/p/abc')).toBe('https://billing.example.com/p/abc')
    expect(billingPortalUrl(undefined)).toBeNull()
    expect(billingPortalUrl('http://billing.example.com')).toBeNull()
    expect(billingPortalUrl('javascript:alert(1)')).toBeNull()
  })
})
