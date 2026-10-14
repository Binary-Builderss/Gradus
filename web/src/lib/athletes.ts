import { queryOptions } from '@tanstack/react-query'
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

const DAY_MS = 86_400_000

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  const letters = parts.length > 1 ? [parts[0], parts[parts.length - 1]] : [parts[0] ?? '?']
  return letters.map((p) => p[0]!.toUpperCase()).join('')
}

/** Giorni di calendario trascorsi da `iso` (0 = oggi). */
export function daysSince(iso: string, now: Date): number {
  const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
  return Math.round((startOfDay(now) - startOfDay(new Date(iso))) / DAY_MS)
}

/** Sedute registrate negli ultimi 7 giorni (oggi incluso) e data dell'ultima. */
export function summarizeWorkouts(timestamps: string[], now: Date) {
  const last = timestamps.reduce<string | null>((a, t) => (a === null || t > a ? t : a), null)
  const recent = timestamps.filter((t) => daysSince(t, now) < 7).length
  return { lastWorkoutAt: last, workoutsLast7Days: recent }
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
