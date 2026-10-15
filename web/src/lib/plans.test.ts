import { describe, expect, it, vi } from 'vitest'

vi.mock('./supabase', () => ({ supabase: {} }))

import { atLimit, billingPortalUrl, checkoutUrl, nearLimit } from './plans'

describe('checkoutUrl', () => {
  it('un https valido passa', () =>
    expect(checkoutUrl('pro', 'https://buy.example.com/abc')).toBe('https://buy.example.com/abc'))
  it('assente o vuoto: nessun acquisto ancora', () => {
    expect(checkoutUrl('pro', '')).toBeNull()
    expect(checkoutUrl('pro', undefined)).toBeNull()
  })
  it('rifiuta http e schemi pericolosi', () => {
    expect(checkoutUrl('pro', 'http://buy.example.com')).toBeNull()
    expect(checkoutUrl('pro', 'javascript:alert(1)')).toBeNull()
  })
  it('legge la variabile del piano richiesto', () => {
    vi.stubEnv('VITE_CHECKOUT_URL_MID', 'https://buy.example.com/mid')
    expect(checkoutUrl('mid')).toBe('https://buy.example.com/mid')
    expect(checkoutUrl('unlimited')).toBeNull()
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
  it('senza tetto non avvisa e non blocca mai', () => {
    expect(nearLimit({ athleteLimit: null, athletes: 500 })).toBe(false)
    expect(atLimit({ athleteLimit: null, athletes: 500 })).toBe(false)
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
