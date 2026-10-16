import { describe, expect, it } from 'vitest'
import { mapAuthError, newPasswordSchema, signupSchema } from './auth'
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
  it('email già registrata e registrazioni chiuse', () => {
    expect(mapAuthError({ code: 'user_already_exists', status: 422 })).toBe(e.emailTaken)
    expect(mapAuthError({ code: 'signup_disabled', status: 422 })).toBe(messages.auth.signup.closed)
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

describe('signupSchema', () => {
  const ok = {
    full_name: 'Giulia Rossi',
    email: 'giulia@example.com',
    password: 'lunghissima',
    confirm: 'lunghissima',
  }
  it('accetta dati validi', () => {
    expect(signupSchema.safeParse(ok).success).toBe(true)
  })
  it('chiede nome, email valida, password di 8 caratteri e conferma uguale', () => {
    expect(signupSchema.safeParse({ ...ok, full_name: '  ' }).error?.issues[0]?.message).toBe(e.nameRequired)
    expect(signupSchema.safeParse({ ...ok, email: 'no' }).error?.issues[0]?.message).toBe(e.emailInvalid)
    expect(
      signupSchema.safeParse({ ...ok, password: 'corta', confirm: 'corta' }).error?.issues[0]?.message,
    ).toBe(e.passwordTooShort)
    expect(signupSchema.safeParse({ ...ok, confirm: 'diversa123' }).error?.issues[0]?.path).toEqual([
      'confirm',
    ])
  })
})
