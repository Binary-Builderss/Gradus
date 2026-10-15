import { queryOptions } from '@tanstack/react-query'
import { addBlock } from './blocks'
import { type GroupKind, kindAfterSlotCount } from './slotRules'
import { supabase } from './supabase'

export type GroupRow = {
  id: string
  session_id: string
  position: number
  kind: GroupKind
  rest_between_s: number
  rest_after_round_s: number
}
export type SlotRow = {
  id: string
  group_id: string
  position: number
  exercise_id: string
  exercise_name: string
}

export const groupsQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['groups', mesocycleId],
    queryFn: async (): Promise<GroupRow[]> => {
      const { data, error } = await supabase
        .from('slot_groups')
        .select('id, session_id, position, kind, rest_between_s, rest_after_round_s')
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
        .order('position')
      if (error) throw error
      return data
    },
  })

export const slotsQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['slots', mesocycleId],
    queryFn: async (): Promise<SlotRow[]> => {
      const { data, error } = await supabase
        .from('slots')
        .select('id, group_id, position, exercise_id, exercise:exercises(name)')
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
        .order('position')
      if (error) throw error
      return data.map(({ exercise, ...s }) => ({ ...s, exercise_name: exercise?.name ?? '' }))
    },
  })

/** Catalogo visibile al coach: esercizi globali e propri. */
export const exercisesQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['exercises', coachId],
    staleTime: 5 * 60_000,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('exercises')
        .select('id, name, owner_id, exercise_muscles(muscle, weight)')
        .is('deleted_at', null)
        .or(`owner_id.is.null,owner_id.eq.${coachId}`)
        .order('name')
      if (error) throw error
      return data.map(({ exercise_muscles, ...e }) => ({
        ...e,
        muscles: [...exercise_muscles].sort((a, b) => b.weight - a.weight),
      }))
    },
  })

/** Nuovo gruppo `single` con un esercizio, in coda alla seduta. */
export async function addExerciseGroup(args: {
  mesocycleId: string
  sessionId: string
  position: number
  exerciseId: string
}) {
  const { data: group, error } = await supabase
    .from('slot_groups')
    .insert({ mesocycle_id: args.mesocycleId, session_id: args.sessionId, position: args.position })
    .select('id')
    .single()
  if (error) throw error
  try {
    const { data: slot, error: slotError } = await supabase
      .from('slots')
      .insert({
        mesocycle_id: args.mesocycleId,
        group_id: group.id,
        position: 0,
        exercise_id: args.exerciseId,
      })
      .select('id')
      .single()
    if (slotError) throw slotError
    await addBlock({ mesocycleId: args.mesocycleId, slotId: slot.id, position: 0 })
  } catch (e) {
    // Niente gruppo vuoto se lo slot o il blocco non sono stati creati.
    await supabase.from('slot_groups').update({ deleted_at: new Date().toISOString() }).eq('id', group.id)
    throw e
  }
}

/** Aggiunge un esercizio a un gruppo esistente; con due esercizi il gruppo smette di essere `single`. */
export async function addSlotToGroup(args: {
  mesocycleId: string
  group: GroupRow
  position: number
  count: number
  exerciseId: string
}) {
  const { data: slot, error } = await supabase
    .from('slots')
    .insert({
      mesocycle_id: args.mesocycleId,
      group_id: args.group.id,
      position: args.position,
      exercise_id: args.exerciseId,
    })
    .select('id')
    .single()
  if (error) throw error
  await addBlock({ mesocycleId: args.mesocycleId, slotId: slot.id, position: 0 })
  await setGroupKind(args.mesocycleId, args.group.id, kindAfterSlotCount(args.group.kind, args.count + 1))
}

/** Toglie un esercizio; senza esercizi il gruppo sparisce, con uno solo torna `single`. */
export async function removeSlot(args: {
  mesocycleId: string
  group: GroupRow
  slotId: string
  count: number
}) {
  const now = new Date().toISOString()
  const { error } = await supabase
    .from('slots')
    .update({ deleted_at: now })
    .eq('id', args.slotId)
    .eq('mesocycle_id', args.mesocycleId)
  if (error) throw error
  if (args.count <= 1) {
    const { error: gError } = await supabase
      .from('slot_groups')
      .update({ deleted_at: now })
      .eq('id', args.group.id)
      .eq('mesocycle_id', args.mesocycleId)
    if (gError) throw gError
  } else {
    await setGroupKind(args.mesocycleId, args.group.id, kindAfterSlotCount(args.group.kind, args.count - 1))
  }
}

export async function setGroupKind(mesocycleId: string, groupId: string, kind: GroupKind) {
  const { error } = await supabase
    .from('slot_groups')
    .update({ kind })
    .eq('id', groupId)
    .eq('mesocycle_id', mesocycleId)
  if (error) throw error
}

export async function setGroupRest(
  mesocycleId: string,
  groupId: string,
  patch: { rest_between_s?: number; rest_after_round_s?: number },
) {
  const { error } = await supabase
    .from('slot_groups')
    .update(patch)
    .eq('id', groupId)
    .eq('mesocycle_id', mesocycleId)
  if (error) throw error
}

export async function reorder(
  table: 'slot_groups' | 'slots' | 'sessions',
  mesocycleId: string,
  changes: { id: string; position: number }[],
) {
  const results = await Promise.all(
    changes.map((c) =>
      supabase.from(table).update({ position: c.position }).eq('id', c.id).eq('mesocycle_id', mesocycleId),
    ),
  )
  const failed = results.find((r) => r.error)
  if (failed?.error) throw failed.error
}
