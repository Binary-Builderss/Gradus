import { describe, expect, it } from 'vitest'
import { buildTourPlan } from './tourPlan'

type Args = Parameters<typeof buildTourPlan>[0]
const full: Args = {
  athleteId: 'a',
  mesocycleId: 'm',
  hasActiveMesocycle: true,
  canFollowSelf: true,
  hasSubscription: true,
  sidebar: true,
}
const plan = (over: Partial<Args> = {}) => buildTourPlan({ ...full, ...over })
const targets = (over: Partial<Args> = {}) => plan(over).map((s) => s.target)
const routes = (over: Partial<Args> = {}) => plan(over).map((s) => s.route.to)

describe('buildTourPlan', () => {
  it('segue il lavoro: atleti, atleta, mesociclo, libreria, template, piano, profilo, personalizza', () => {
    const order = routes().filter((to, i, all) => to !== all[i - 1])
    expect(order).toEqual([
      '/',
      '/atleti/$athleteId',
      '/mesocicli/$mesocycleId',
      '/esercizi',
      '/template',
      '/piani',
      '/profilo',
      '/personalizza',
    ])
  })

  it('nel mesociclo copre scrittura, riepilogo e PDF', () => {
    const inMeso = plan()
      .filter((s) => s.route.to === '/mesocicli/$mesocycleId')
      .map((s) => s.target)
    expect(inMeso).toEqual([
      'meso-settings',
      'meso-status',
      'session-tabs',
      'session-header',
      'add-exercise',
      'grid',
      'measure',
      'week-copy',
      'row-options',
      'fill-help',
      'order-superset',
      'save-status',
      'meso-tabs',
      'pdf-button',
    ])
  })

  it('ogni passo ha titolo e testo', () => {
    for (const s of plan()) {
      expect(s.title.length).toBeGreaterThan(2)
      expect(s.body.length).toBeGreaterThan(20)
    }
  })

  it('senza atleti sostituisce le pagine dell’atleta con una spiegazione', () => {
    const p = plan({ athleteId: null, mesocycleId: null })
    expect(p.some((s) => s.route.to === '/atleti/$athleteId')).toBe(false)
    expect(p.find((s) => s.target === undefined && s.route.to === '/')).toBeDefined()
  })

  it('senza mesociclo si ferma alla pagina dell’atleta', () => {
    const p = plan({ mesocycleId: null })
    expect(p.some((s) => s.route.to === '/mesocicli/$mesocycleId')).toBe(false)
    expect(p.some((s) => s.route.to === '/atleti/$athleteId')).toBe(true)
  })

  it('i passi condizionali compaiono solo quando servono', () => {
    expect(targets()).toContain('athlete-overview')
    expect(targets({ hasActiveMesocycle: false })).not.toContain('athlete-overview')
    expect(targets()).toContain('follow-self')
    expect(targets({ canFollowSelf: false })).not.toContain('follow-self')
    expect(targets()).toContain('subscription')
    expect(targets({ hasSubscription: false })).not.toContain('subscription')
  })

  it('su schermo piccolo niente passi sulla barra laterale', () => {
    const small = targets({ sidebar: false })
    expect(small).not.toContain('nav-athletes')
    expect(small).not.toContain('nav-collapse')
    expect(targets()).toContain('nav-athletes')
    expect(targets()).toContain('nav-collapse')
  })
})
