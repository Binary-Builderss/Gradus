import { messages } from './messages'

const m = messages.app.mesocycle.status

/** Esito di un cambio di stato rifiutato dal database, in parole per il coach. */
export function statusErrorMessage(
  error: { message?: string; hint?: string | null } | null | undefined,
): string {
  const code = error?.message ?? ''
  if (code.includes('mesocycle_empty')) return m.errors.empty
  if (code.includes('athlete_has_active')) return m.errors.hasActive(error?.hint ?? '')
  if (code.includes('mesocycle_has_workouts')) return m.errors.hasWorkouts
  if (code.includes('mesocycle_status_change_not_allowed')) return m.errors.notAllowed
  return m.errors.generic
}
