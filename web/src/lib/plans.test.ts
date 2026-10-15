import { describe, expect, it } from 'vitest'
import { proCheckoutUrl } from './plans'

describe('proCheckoutUrl', () => {
  it('un https valido passa', () =>
    expect(proCheckoutUrl('https://buy.example.com/abc')).toBe('https://buy.example.com/abc'))
  it('assente o vuoto: nessun acquisto ancora', () => {
    expect(proCheckoutUrl(undefined)).toBeNull()
    expect(proCheckoutUrl('')).toBeNull()
  })
  it('rifiuta http e schemi pericolosi', () => {
    expect(proCheckoutUrl('http://buy.example.com')).toBeNull()
    expect(proCheckoutUrl('javascript:alert(1)')).toBeNull()
  })
})
