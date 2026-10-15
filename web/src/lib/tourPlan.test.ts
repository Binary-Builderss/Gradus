import { describe, expect, it } from 'vitest'
import { buildTourPlan } from './tourPlan'

const targets = (args: Parameters<typeof buildTourPlan>[0]) => buildTourPlan(args).map((s) => s.target)

describe('buildTourPlan', () => {
  it('walks athletes, athlete, mesocycle and library when data exists', () => {
    const plan = buildTourPlan({ athleteId: 'a', mesocycleId: 'm', hasActiveMesocycle: false, sidebar: true })
    expect(plan.map((s) => s.route.to)).toEqual([
      '/',
      '/',
      '/',
      '/atleti/$athleteId',
      '/atleti/$athleteId',
      '/mesocicli/$mesocycleId',
      '/mesocicli/$mesocycleId',
      '/mesocicli/$mesocycleId',
      '/mesocicli/$mesocycleId',
      '/mesocicli/$mesocycleId',
      '/mesocicli/$mesocycleId',
      '/mesocicli/$mesocycleId',
      '/esercizi',
      '/esercizi',
    ])
  })

  it('replaces the athlete pages with one explanation when there is no athlete', () => {
    const plan = buildTourPlan({
      athleteId: null,
      mesocycleId: null,
      hasActiveMesocycle: false,
      sidebar: true,
    })
    expect(plan.map((s) => s.route.to)).toEqual(['/', '/', '/', '/', '/esercizi', '/esercizi'])
    expect(plan[3]!.target).toBeUndefined()
  })

  it('stops at the athlete page when there is no mesocycle', () => {
    const plan = buildTourPlan({
      athleteId: 'a',
      mesocycleId: null,
      hasActiveMesocycle: false,
      sidebar: true,
    })
    expect(plan.some((s) => s.route.to === '/mesocicli/$mesocycleId')).toBe(false)
    expect(plan.some((s) => s.route.to === '/atleti/$athleteId')).toBe(true)
  })

  it('shows the overview step only when the athlete has an active mesocycle', () => {
    const base = { athleteId: 'a', mesocycleId: 'm', sidebar: true }
    expect(targets({ ...base, hasActiveMesocycle: true })).toContain('athlete-overview')
    expect(targets({ ...base, hasActiveMesocycle: false })).not.toContain('athlete-overview')
  })

  it('leaves out the sidebar step on small screens', () => {
    expect(
      targets({ athleteId: null, mesocycleId: null, hasActiveMesocycle: false, sidebar: false }),
    ).not.toContain('nav-athletes')
    expect(
      targets({ athleteId: null, mesocycleId: null, hasActiveMesocycle: false, sidebar: true }),
    ).toContain('nav-athletes')
  })
})
