import { describe, expect, it } from 'vitest'
import { mapAuthError, newPasswordSchema } from './auth'
import { messages } from './messages'

const e = messages.auth.errors

describe('mapAuthError', () => {
  it('credenziali sbagliate', () => {
    expect(mapAuthError({ code: 'invalid_credentials', status: 400 })).toBe(e.invalidCredentials)
  })
  it('troppi tentativi, per codice o per stato 429', () => {
    expect(mapAuthError({ code: 'over_request_rate_limit' })).toBe(e.rateLimit)
    expect(mapAuthError({ status: 429 })).toBe(e.rateLimit)
  })
  it('rete assente', () => {
    expect(mapAuthError({ name: 'AuthRetryableFetchError', status: 0 })).toBe(e.network)
  })
  it('errore sconosciuto', () => {
    expect(mapAuthError({ code: 'unexpected_failure', status: 500 })).toBe(e.generic)
  })
})

describe('newPasswordSchema', () => {
  it('rifiuta password corte e conferme diverse', () => {
    const short = newPasswordSchema.safeParse({ password: 'corta', confirm: 'corta' })
    expect(short.error?.issues[0]?.message).toBe(e.passwordTooShort)
    const mismatch = newPasswordSchema.safeParse({ password: 'lunghissima', confirm: 'diversa123' })
    expect(mismatch.error?.issues[0]?.path).toEqual(['confirm'])
  })
})
