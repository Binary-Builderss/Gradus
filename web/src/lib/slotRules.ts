export type GroupKind = 'single' | 'superset' | 'giant' | 'circuit' | 'jumpset'

export const GROUP_KINDS: readonly GroupKind[] = ['single', 'superset', 'giant', 'circuit', 'jumpset']

/**
 * Un gruppo `single` ha un solo esercizio; con più esercizi non può restare `single`.
 * Con un solo esercizio rimasto un gruppo concatenato torna `single`.
 */
export function kindAfterSlotCount(kind: GroupKind, count: number): GroupKind {
  if (count <= 1) return 'single'
  return kind === 'single' ? 'superset' : kind
}

/** Nuove posizioni 0..n-1 per gli id nell'ordine dato; solo quelle cambiate rispetto a `current`. */
export function positionChanges(
  orderedIds: readonly string[],
  current: readonly { id: string; position: number }[],
): { id: string; position: number }[] {
  const byId = new Map(current.map((c) => [c.id, c.position]))
  return orderedIds.flatMap((id, position) => (byId.get(id) === position ? [] : [{ id, position }]))
}

/** Filtro per la ricerca nel catalogo: ignora maiuscole e accenti. */
export function matchesSearch(name: string, query: string): boolean {
  const norm = (s: string) =>
    s
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLowerCase()
  return norm(name).includes(norm(query.trim()))
}

export const MUSCLE_GROUPS = ['chest', 'back', 'shoulders', 'arms', 'legs', 'core'] as const
export type MuscleGroup = (typeof MUSCLE_GROUPS)[number]

const GROUP_OF: Record<string, MuscleGroup> = {
  chest: 'chest',
  lats: 'back',
  upper_back: 'back',
  traps: 'back',
  lower_back: 'back',
  front_delts: 'shoulders',
  side_delts: 'shoulders',
  rear_delts: 'shoulders',
  biceps: 'arms',
  triceps: 'arms',
  forearms: 'arms',
  quads: 'legs',
  hamstrings: 'legs',
  glutes: 'legs',
  adductors: 'legs',
  abductors: 'legs',
  calves: 'legs',
  abs: 'core',
}

/** Gruppo muscolare principale dell'esercizio: quello del muscolo con il peso maggiore. */
export function muscleGroupOf(muscles: readonly { muscle: string; weight: number }[]): MuscleGroup | null {
  const main = muscles.reduce<{ muscle: string; weight: number } | null>(
    (best, m) => (best === null || m.weight > best.weight ? m : best),
    null,
  )
  return main ? (GROUP_OF[main.muscle] ?? null) : null
}
