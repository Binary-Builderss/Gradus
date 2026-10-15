import { queryOptions } from '@tanstack/react-query'
import { summarizeWorkouts } from './athleteStats'
import { supabase } from './supabase'

export type AthleteRow = {
  id: string
  name: string
  email: string | null
  status: 'active' | 'pending'
  isSelf: boolean
  lastWorkoutAt: string | null
  workoutsLast7Days: number
}

async function fetchAthletes(coachId: string): Promise<AthleteRow[]> {
  const { data: links, error } = await supabase
    .from('coach_athletes')
    .select('athlete_id, status, athlete:profiles!coach_athletes_athlete_id_fkey(full_name, email)')
    .eq('coach_id', coachId)
    .in('status', ['active', 'pending'])
    .order('created_at')
  if (error) throw error

  const activeIds = links.filter((l) => l.status === 'active').map((l) => l.athlete_id)
  const byAthlete = new Map<string, string[]>()
  if (activeIds.length > 0) {
    // ponytail: ultime 500 sedute di tutti gli atleti; per molti atleti passare a una vista SQL.
    const { data: workouts, error: wError } = await supabase
      .from('workouts')
      .select('athlete_id, updated_at')
      .in('athlete_id', activeIds)
      .is('deleted_at', null)
      .order('updated_at', { ascending: false })
      .limit(500)
    if (wError) throw wError
    for (const w of workouts)
      byAthlete.set(w.athlete_id, [...(byAthlete.get(w.athlete_id) ?? []), w.updated_at])
  }

  const now = new Date()
  return links.map((l) => {
    const email = l.athlete?.email ?? null
    return {
      id: l.athlete_id,
      name: l.athlete?.full_name?.trim() || email || '-',
      email,
      status: l.status as 'active' | 'pending',
      isSelf: l.athlete_id === coachId,
      ...summarizeWorkouts(byAthlete.get(l.athlete_id) ?? [], now),
    }
  })
}

export const athletesQuery = (coachId: string) =>
  queryOptions({ queryKey: ['athletes', coachId], queryFn: () => fetchAthletes(coachId) })

/**
 * Il coach si segue da solo: un collegamento con sé stesso (coach_id = athlete_id), con lo stesso account e senza
 * una seconda email. Non occupa un posto del piano. L'app atleta mostra poi i suoi programmi come a ogni atleta.
 */
export async function followSelf(userId: string) {
  const { error } = await supabase
    .from('coach_athletes')
    .upsert({ coach_id: userId, athlete_id: userId, status: 'active' }, { onConflict: 'coach_id,athlete_id' })
  if (error) throw error
}
