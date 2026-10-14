// Helper puri della lista atleti: nessuna dipendenza da Supabase, quindi testabili senza variabili d'ambiente.
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
