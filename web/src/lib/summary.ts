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

export type ProgressRow = {
  exerciseId: string
  exerciseName: string
  week: number
  setsPrescribed: number
  setsDone: number
  topLoadKg: number | null
  topReps: number | null
  e1rm: number | null
}

/** Miglior serie, serie fatte e prescritte per esercizio e settimana (funzione SQL). */
export const exerciseProgressQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['exercise-progress', mesocycleId],
    staleTime: 0,
    queryFn: async (): Promise<ProgressRow[]> => {
      const { data, error } = await supabase.rpc('weekly_exercise_progress', { p_mesocycle_id: mesocycleId })
      if (error) throw error
      // I tipi generati non conoscono i null delle colonne calcolate con left join.
      return data.map((r) => ({
        exerciseId: r.exercise_id,
        exerciseName: r.exercise_name,
        week: r.week,
        setsPrescribed: r.sets_prescribed,
        setsDone: r.sets_done,
        topLoadKg: r.top_load_kg as number | null,
        topReps: r.top_reps as number | null,
        e1rm: r.e1rm as number | null,
      }))
    },
  })

export type ExerciseProgress = {
  exerciseId: string
  name: string
  weeks: {
    setsPrescribed: number
    setsDone: number
    topLoadKg: number | null
    topReps: number | null
    e1rm: number | null
  }[]
  /** Differenza tra l'ultima e la prima stima del massimale registrate; null con meno di due settimane di dati. */
  e1rmChange: number | null
  bestE1rm: number | null
}

/** Una riga per esercizio, in ordine alfabetico; settimane senza dati a zero. */
export function buildProgressTable(rows: readonly ProgressRow[], totalWeeks: number): ExerciseProgress[] {
  const byExercise = new Map<string, ExerciseProgress>()
  for (const r of rows) {
    if (r.week < 1 || r.week > totalWeeks) continue
    let entry = byExercise.get(r.exerciseId)
    if (!entry) {
      entry = {
        exerciseId: r.exerciseId,
        name: r.exerciseName,
        weeks: Array.from({ length: totalWeeks }, () => ({
          setsPrescribed: 0,
          setsDone: 0,
          topLoadKg: null,
          topReps: null,
          e1rm: null,
        })),
        e1rmChange: null,
        bestE1rm: null,
      }
      byExercise.set(r.exerciseId, entry)
    }
    entry.weeks[r.week - 1] = {
      setsPrescribed: r.setsPrescribed,
      setsDone: r.setsDone,
      topLoadKg: r.topLoadKg,
      topReps: r.topReps,
      e1rm: r.e1rm,
    }
  }
  for (const entry of byExercise.values()) {
    const estimates = entry.weeks.flatMap((w) => (w.e1rm === null ? [] : [w.e1rm]))
    entry.bestE1rm = estimates.length > 0 ? Math.max(...estimates) : null
    entry.e1rmChange = estimates.length > 1 ? estimates[estimates.length - 1]! - estimates[0]! : null
  }
  return [...byExercise.values()].sort((a, b) => a.name.localeCompare(b.name))
}

/** Con segno e virgola italiana: «+4,5», «−2», «0». */
export function formatChange(n: number): string {
  const rounded = Math.round(n * 10) / 10
  const text = formatVolume(Math.abs(rounded))
  return rounded > 0 ? `+${text}` : rounded < 0 ? `\u2212${text}` : text
}
