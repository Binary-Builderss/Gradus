import { useQueryClient, type QueryClient } from '@tanstack/react-query'
import { useRouter } from '@tanstack/react-router'
import { driver, type DriveStep } from 'driver.js'
import { useCallback } from 'react'
import 'driver.js/dist/driver.css'
import { athletesQuery } from '@/lib/athletes'
import { mesocyclesQuery } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { buildTourPlan, type TourRoute } from '@/lib/tourPlan'

const m = messages.app.tour

/** Primo elemento visibile con quel `data-tour` (la barra laterale esiste nel DOM anche quando è nascosta). */
const findTarget = (target: string) =>
  [...document.querySelectorAll<HTMLElement>(`[data-tour="${target}"]`)].find(
    (el) => el.getClientRects().length > 0,
  ) ?? null

/** Un atleta collegato e un suo mesociclo su cui mostrare le pagine; null se ancora non ci sono. */
async function findExamples(queryClient: QueryClient, coachId: string) {
  try {
    const athletes = await queryClient.ensureQueryData(athletesQuery(coachId))
    const linked = athletes.filter((a) => a.status === 'active').slice(0, 5)
    for (const a of linked) {
      const list = await queryClient.ensureQueryData(mesocyclesQuery(a.id))
      if (list[0])
        return {
          athleteId: a.id,
          mesocycleId: list[0].id,
          hasActiveMesocycle: list.some((x) => x.status === 'active'),
        }
    }
    return { athleteId: linked[0]?.id ?? null, mesocycleId: null, hasActiveMesocycle: false }
  } catch {
    return { athleteId: null, mesocycleId: null, hasActiveMesocycle: false }
  }
}

const sameRoute = (a: TourRoute, b: TourRoute) => JSON.stringify(a) === JSON.stringify(b)

/**
 * Guida a passi sulle pagine reali: evidenzia un elemento alla volta e porta da solo da una pagina
 * all'altra. Non si può cliccare l'elemento evidenziato, quindi la guida non modifica nulla.
 */
export function useGuidedTour(coachId: string) {
  const router = useRouter()
  const queryClient = useQueryClient()

  return useCallback(async () => {
    const examples = await findExamples(queryClient, coachId)
    const plan = buildTourPlan({ ...examples, sidebar: window.matchMedia('(min-width: 1024px)').matches })
    await router.navigate(plan[0]!.route)

    async function goTo(index: number) {
      const next = plan[index]
      if (!next) return tour.destroy()
      const current = plan[tour.getActiveIndex() ?? index]
      if (current && !sameRoute(current.route, next.route)) await router.navigate(next.route)
      tour.moveTo(index)
    }

    const steps: DriveStep[] = plan.map((p, i) => ({
      // Il primo passo di ogni pagina aspetta che la pagina si carichi.
      waitForElement: i === 0 || !sameRoute(plan[i - 1]!.route, p.route) ? 3000 : 0,
      element: p.target ? () => findTarget(p.target!) as HTMLElement : undefined,
      // Accanto alla barra laterale il fumetto va a destra, non sopra le altre voci.
      popover: {
        title: p.title,
        description: p.body,
        side: p.target?.startsWith('nav-') ? 'right' : 'bottom',
      },
    }))

    const tour = driver({
      steps,
      popoverClass: 'gradus-tour',
      showProgress: true,
      progressText: m.progress,
      nextBtnText: m.next,
      prevBtnText: m.prev,
      doneBtnText: m.done,
      closeBtnLabel: m.close,
      overlayOpacity: 0.55,
      stagePadding: 6,
      stageRadius: 6,
      smoothScroll: true,
      disableActiveInteraction: true,
      onNextClick: () => void goTo((tour.getActiveIndex() ?? 0) + 1),
      onPrevClick: () => void goTo((tour.getActiveIndex() ?? 1) - 1),
      onDoneClick: () => tour.destroy(),
    })
    tour.drive(0)
  }, [queryClient, router, coachId])
}
