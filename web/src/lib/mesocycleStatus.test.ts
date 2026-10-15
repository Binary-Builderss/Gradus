import { describe, expect, it } from 'vitest'
import { statusErrorMessage } from './mesocycleStatus'

describe('statusErrorMessage', () => {
  it('mesociclo vuoto: dice cosa aggiungere', () =>
    expect(statusErrorMessage({ message: 'mesocycle_empty' })).toContain('almeno una seduta'))
  it('atleta con un altro attivo: nomina quello attivo', () =>
    expect(statusErrorMessage({ message: 'athlete_has_active', hint: 'Blocco 1' })).toContain('«Blocco 1»'))
  it('sedute registrate: non si ritira', () =>
    expect(statusErrorMessage({ message: 'mesocycle_has_workouts' })).toContain('già registrato'))
  it('passaggio non ammesso e errori sconosciuti', () => {
    expect(statusErrorMessage({ message: 'mesocycle_status_change_not_allowed' })).toContain('non si può')
    expect(statusErrorMessage({ message: 'boh' })).toContain('Riprova')
    expect(statusErrorMessage(null)).toContain('Riprova')
  })
})
