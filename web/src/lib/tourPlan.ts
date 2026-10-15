import { messages } from '@/lib/messages'

const t = messages.app.tour.steps

export type TourRoute =
  | { to: '/' }
  | { to: '/esercizi' }
  | { to: '/atleti/$athleteId'; params: { athleteId: string } }
  | { to: '/mesocicli/$mesocycleId'; params: { mesocycleId: string } }

/** Un passo della guida: la pagina in cui sta e l'elemento da evidenziare (`data-tour`), se c'è. */
export type TourStep = {
  route: TourRoute
  target?: string
  title: string
  body: string
}

const step = (route: TourRoute, text: { title: string; body: string }, target?: string): TourStep => ({
  route,
  target,
  ...text,
})

/**
 * Percorso della guida: atleti → atleta → mesociclo → libreria.
 * Le pagine che dipendono dai dati (atleta, mesociclo) si saltano con un passo di spiegazione se i dati non ci sono.
 */
export function buildTourPlan(args: {
  athleteId: string | null
  mesocycleId: string | null
  /** La barra laterale esiste solo da schermo largo. */
  sidebar: boolean
}): TourStep[] {
  const home: TourRoute = { to: '/' }
  const plan: TourStep[] = []
  if (args.sidebar) plan.push(step(home, t.navAthletes, 'nav-athletes'))
  plan.push(step(home, t.invite, 'invite'), step(home, t.athleteList, 'athlete-list'))

  if (!args.athleteId) {
    plan.push(step(home, t.noAthlete))
  } else {
    const athlete: TourRoute = { to: '/atleti/$athleteId', params: { athleteId: args.athleteId } }
    plan.push(step(athlete, t.newMesocycle, 'new-mesocycle'))
    if (!args.mesocycleId) {
      plan.push(step(athlete, t.noMesocycle))
    } else {
      const meso: TourRoute = { to: '/mesocicli/$mesocycleId', params: { mesocycleId: args.mesocycleId } }
      plan.push(
        step(athlete, t.mesocycleList, 'mesocycle-list'),
        step(meso, t.settings, 'meso-settings'),
        step(meso, t.sessions, 'session-tabs'),
        step(meso, t.addExercise, 'add-exercise'),
        step(meso, t.grid, 'grid'),
        step(meso, t.fill, 'fill-help'),
        step(meso, t.save, 'save-status'),
      )
    }
  }

  const library: TourRoute = { to: '/esercizi' }
  plan.push(step(library, t.exercises, 'exercise-new'), step(library, t.finish))
  return plan
}
