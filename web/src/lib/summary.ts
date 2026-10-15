import { queryOptions } from '@tanstack/react-query'
import type { Database } from './database.types'
import { supabase } from './supabase'

export type Muscle = Database['public']['Enums']['muscle']
export type VolumeRow = { week: number; muscle: Muscle; prescribed: number; executed: number }

/** Serie per muscolo e settimana, prescritte ed eseguite (funzione SQL: la logica sta nel database). */
export const weeklyVolumeQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['weekly-volume', mesocycleId],
    // Dipende da tutto ciò che si scrive nell'editor: si rilegge a ogni apertura del riepilogo.
    staleTime: 0,
    queryFn: async (): Promise<VolumeRow[]> => {
      const { data, error } = await supabase.rpc('weekly_muscle_volume', { p_mesocycle_id: mesocycleId })
      if (error) throw error
      return data
    },
  })

/** Sedute registrate dall'atleta: (seduta, settimana) già eseguite. */
export const doneWorkoutsQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['done-workouts', mesocycleId],
    staleTime: 0,
    queryFn: async (): Promise<{ session_id: string; week: number }[]> => {
      const { data, error } = await supabase
        .from('workouts')
        .select('session_id, week')
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
      if (error) throw error
      return data
    },
  })

export type MuscleVolume = {
  muscle: Muscle
  /** Indice 0 = settimana 1. */
  weeks: { prescribed: number; executed: number }[]
  total: number
}

/** Una riga per muscolo, dal più allenato al meno; settimane senza dati a zero. */
export function buildVolumeTable(rows: readonly VolumeRow[], totalWeeks: number): MuscleVolume[] {
  const byMuscle = new Map<Muscle, MuscleVolume>()
  for (const r of rows) {
    if (r.week < 1 || r.week > totalWeeks) continue
    let entry = byMuscle.get(r.muscle)
    if (!entry) {
      entry = {
        muscle: r.muscle,
        weeks: Array.from({ length: totalWeeks }, () => ({ prescribed: 0, executed: 0 })),
        total: 0,
      }
      byMuscle.set(r.muscle, entry)
    }
    entry.weeks[r.week - 1] = { prescribed: r.prescribed, executed: r.executed }
    entry.total += r.prescribed
  }
  return [...byMuscle.values()].sort((a, b) => b.total - a.total || a.muscle.localeCompare(b.muscle))
}

/** Intensità del colore di fondo (0..100) di una cella rispetto al massimo della tabella. */
export function heatPercent(value: number, max: number): number {
  return max > 0 && value > 0 ? Math.round(12 + (value / max) * 38) : 0
}

/** Numero con al massimo un decimale e virgola italiana: 4 → «4», 4.5 → «4,5». */
export const formatVolume = (n: number) => String(Math.round(n * 10) / 10).replace('.', ',')
