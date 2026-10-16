import { describe, expect, it } from 'vitest'
import { contentLimitReached } from './planErrors'

describe('contentLimitReached', () => {
  it('riconosce il tetto dei template e porta il numero', () => {
    expect(
      contentLimitReached({ code: 'P0001', message: 'mesocycle_templates_limit_reached', hint: '5' }),
    ).toEqual({
      kind: 'mesocycle_templates',
      limit: 5,
    })
  })
  it('riconosce quello delle progressioni', () => {
    expect(contentLimitReached({ message: 'progression_presets_limit_reached', hint: '20' })?.kind).toBe(
      'progression_presets',
    )
  })
  it('senza hint il tetto è ignoto; un altro errore non è un tetto', () => {
    expect(contentLimitReached({ message: 'mesocycle_templates_limit_reached' })?.limit).toBeNull()
    expect(contentLimitReached({ code: '23505', message: 'duplicate key' })).toBeNull()
    expect(contentLimitReached(null)).toBeNull()
  })
})
