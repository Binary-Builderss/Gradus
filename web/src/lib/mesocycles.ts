import { queryOptions } from '@tanstack/react-query'
import { clampDeload } from './mesocycleSchema'
import { supabase } from './supabase'

export type MesocycleStatus = 'draft' | 'active' | 'completed'

export const athleteQuery = (coachId: string, athleteId: string) =>
  queryOptions({
    queryKey: ['athlete', coachId, athleteId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('coach_athletes')
        .select('status, athlete:profiles!coach_athletes_athlete_id_fkey(full_name, email)')
        .eq('coach_id', coachId)
        .eq('athlete_id', athleteId)
        .maybeSingle()
      if (error) throw error
      return data
    },
  })

export const mesocyclesQuery = (athleteId: string) =>
  queryOptions({
    queryKey: ['mesocycles', athleteId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('mesocycles')
        .select('id, name, start_date, weeks, status')
        .eq('athlete_id', athleteId)
        .order('start_date', { ascending: false })
      if (error) throw error
      return data
    },
  })

export async function createMesocycle(
  athleteId: string,
  values: { name: string; start_date: string; weeks: number },
) {
  const { data, error } = await supabase
    .from('mesocycles')
    .insert({ athlete_id: athleteId, ...values })
    .select('id')
    .single()
  if (error) throw error
  return data.id
}

export const mesocycleQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['mesocycle', mesocycleId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('mesocycles')
        .select('id, athlete_id, name, start_date, weeks, deload_weeks, status')
        .eq('id', mesocycleId)
        .maybeSingle()
      if (error) throw error
      return data
    },
  })

export async function updateMesocycle(
  mesocycleId: string,
  patch: { name?: string; weeks?: number; deload_weeks?: number[] },
) {
  const { error } = await supabase.from('mesocycles').update(patch).eq('id', mesocycleId)
  if (error) throw error
}

/** Cambia la durata tenendo coerenti gli scarichi: nessuna settimana oltre quelle del mesociclo. */
export function updateWeeks(mesocycleId: string, weeks: number, deload: readonly number[]) {
  return updateMesocycle(mesocycleId, { weeks, deload_weeks: clampDeload(deload, weeks) })
}

export const sessionsQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['sessions', mesocycleId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('sessions')
        .select('id, position, name')
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
        .order('position')
      if (error) throw error
      return data
    },
  })

export async function addSession(mesocycleId: string, position: number, name: string) {
  const { data, error } = await supabase
    .from('sessions')
    .insert({ mesocycle_id: mesocycleId, position, name })
    .select('id')
    .single()
  if (error) throw error
  return data.id
}

export async function renameSession(sessionId: string, mesocycleId: string, name: string) {
  const { error } = await supabase
    .from('sessions')
    .update({ name })
    .eq('id', sessionId)
    .eq('mesocycle_id', mesocycleId)
  if (error) throw error
}

export async function deleteSession(sessionId: string, mesocycleId: string) {
  const { error } = await supabase
    .from('sessions')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', sessionId)
    .eq('mesocycle_id', mesocycleId)
  if (error) throw error
}
