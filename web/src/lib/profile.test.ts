import { describe, expect, it, vi } from 'vitest'

vi.mock('./supabase', () => ({ supabase: {} }))

import { displayName } from './profile'

describe('displayName', () => {
  it('il nome scelto vince sull’email', () =>
    expect(displayName({ fullName: ' Giulia Rossi ', email: 'g@x.it' })).toBe('Giulia Rossi'))
  it('senza nome compare l’email', () =>
    expect(displayName({ fullName: null, email: 'g@x.it' })).toBe('g@x.it'))
  it('un nome fatto di spazi vale come vuoto', () =>
    expect(displayName({ fullName: '  ', email: 'g@x.it' })).toBe('g@x.it'))
  it('senza profilo usa il valore di riserva', () => expect(displayName(undefined, 'coach')).toBe('coach'))
})
