import { messages } from '@/lib/messages'

const t = messages.app.tour.steps

export type TourRoute =
  | { to: '/' }
  | { to: '/esercizi' }
  | { to: '/template' }
  | { to: '/profilo' }
  | { to: '/personalizza' }
  | { to: '/piani' }
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
 * Percorso della guida, in ordine di lavoro: atleti → atleta → mesociclo (scrivere, riepilogo, PDF) → libreria →
 * piano → profilo → personalizza. Le pagine che dipendono dai dati (atleta, mesociclo) si saltano con un passo
 * di spiegazione se i dati non ci sono; i passi che valgono solo in certe condizioni (seguirsi da soli,
 * abbonamento, schermo largo) compaiono solo allora.
 */
export function buildTourPlan(args: {
  athleteId: string | null
  mesocycleId: string | null
  /** L'atleta ha un mesociclo attivo: solo allora la pagina mostra la panoramica. */
  hasActiveMesocycle: boolean
  /** Il coach non si è ancora aggiunto come atleta di sé stesso. */
  canFollowSelf: boolean
  /** Ha un abbonamento a pagamento: solo allora la pagina del piano mostra la disdetta. */
  hasSubscription: boolean
  /** La barra laterale esiste solo da schermo largo. */
  sidebar: boolean
}): TourStep[] {
  const home: TourRoute = { to: '/' }
  const plan: TourStep[] = []
  if (args.sidebar)
    plan.push(step(home, t.navAthletes, 'nav-athletes'), step(home, t.collapse, 'nav-collapse'))
  plan.push(step(home, t.invite, 'invite'))
  if (args.canFollowSelf) plan.push(step(home, t.followSelf, 'follow-self'))
  plan.push(step(home, t.athleteList, 'athlete-list'))

  if (!args.athleteId) {
    plan.push(step(home, t.noAthlete))
  } else {
    const athlete: TourRoute = { to: '/atleti/$athleteId', params: { athleteId: args.athleteId } }
    if (args.hasActiveMesocycle) plan.push(step(athlete, t.overview, 'athlete-overview'))
    plan.push(step(athlete, t.bestSets, 'best-sets'), step(athlete, t.newMesocycle, 'new-mesocycle'))
    if (!args.mesocycleId) {
      plan.push(step(athlete, t.noMesocycle))
    } else {
      const meso: TourRoute = { to: '/mesocicli/$mesocycleId', params: { mesocycleId: args.mesocycleId } }
      plan.push(
        step(athlete, t.mesocycleList, 'mesocycle-list'),
        step(meso, t.settings, 'meso-settings'),
        step(meso, t.status, 'meso-status'),
        step(meso, t.sessions, 'session-tabs'),
        step(meso, t.sessionHeader, 'session-header'),
        step(meso, t.addExercise, 'add-exercise'),
        step(meso, t.grid, 'grid'),
        step(meso, t.measure, 'measure'),
        step(meso, t.weekCopy, 'week-copy'),
        step(meso, t.rowOptions, 'row-options'),
        step(meso, t.fill, 'fill-help'),
        step(meso, t.orderSuperset, 'order-superset'),
        step(meso, t.save, 'save-status'),
        step(meso, t.summary, 'meso-tabs'),
        step(meso, t.pdf, 'pdf-button'),
      )
    }
  }

  const library: TourRoute = { to: '/esercizi' }
  const plans: TourRoute = { to: '/piani' }
  const profile: TourRoute = { to: '/profilo' }
  const customize: TourRoute = { to: '/personalizza' }
  plan.push(
    step(library, t.exercises, 'exercise-new'),
    step(library, t.exerciseList, 'exercise-list'),
    step({ to: '/template' }, t.templates, 'template-list'),
    step(plans, t.plans, 'plans'),
  )
  if (args.hasSubscription) plan.push(step(plans, t.subscription, 'subscription'))
  plan.push(
    step(profile, t.account, 'account-menu'),
    step(profile, t.profile, 'profile-form'),
    step(profile, t.security, 'security'),
    step(profile, t.danger, 'danger-zone'),
    step(customize, t.brand, 'brand-form'),
    step(customize, t.finish),
  )
  return plan
}
