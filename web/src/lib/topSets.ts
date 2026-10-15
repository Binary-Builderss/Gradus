import { queryOptions } from '@tanstack/react-query'
import { supabase } from './supabase'

export type BestSet = {
  exercise_id: string
  exercise_name: string
  best_load_kg: number
  best_reps: number
  best_e1rm: number
  best_on: string
  workouts: number
  last_on: string
}

export type TopSetPoint = {
  workout_id: string
  mesocycle_name: string
  week: number
  performed_on: string
  load_kg: number
  reps: number
  e1rm: number
}

/** La miglior serie di ogni esercizio dell'atleta, tra tutti i mesocicli (funzione SQL `athlete_best_sets`, solo per il suo coach). */
export const bestSetsQuery = (coachId: string, athleteId: string) =>
  queryOptions({
    queryKey: ['best-sets', coachId, athleteId],
    queryFn: async (): Promise<BestSet[]> => {
      const { data, error } = await supabase.rpc('athlete_best_sets', { p_athlete_id: athleteId })
      if (error) throw error
      return data
    },
  })

/** Una riga per seduta: la miglior serie di quel giorno su quell'esercizio (`top_set_history`). */
export const topSetHistoryQuery = (athleteId: string, exerciseId: string) =>
  queryOptions({
    queryKey: ['top-set-history', athleteId, exerciseId],
    queryFn: async (): Promise<TopSetPoint[]> => {
      const { data, error } = await supabase.rpc('top_set_history', {
        p_athlete_id: athleteId,
        p_exercise_id: exerciseId,
      })
      if (error) throw error
      return [...data].sort((a, b) => a.performed_on.localeCompare(b.performed_on))
    },
  })
