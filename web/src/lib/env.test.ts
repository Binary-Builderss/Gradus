import { describe, expect, it } from 'vitest'
import { parseEnv } from './env'

describe('parseEnv', () => {
  it('accetta URL e anon key validi', () => {
    const env = parseEnv({
      VITE_SUPABASE_URL: 'http://127.0.0.1:54321',
      VITE_SUPABASE_ANON_KEY: 'anon-key',
    })
    expect(env.VITE_SUPABASE_URL).toBe('http://127.0.0.1:54321')
  })

  it('segnala le variabili mancanti', () => {
    expect(() => parseEnv({})).toThrow(/VITE_SUPABASE_URL/)
  })
})
