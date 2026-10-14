import { queryOptions } from '@tanstack/react-query'
import type { Json } from './database.types'
import type { CellOp, BlockData, BlockRole, Technique, WeekData } from './gridModel'
import { supabase } from './supabase'

const BLOCK_COLUMNS =
  'id, slot_id, position, role, technique, tut_eccentric_s, tut_bottom_pause_s, tut_concentric_s, tut_top_pause_s, rest_s, prep_s, ref_block_id'

export const blocksQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['blocks', mesocycleId],
    queryFn: async (): Promise<BlockData[]> => {
      const { data, error } = await supabase
        .from('set_blocks')
        .select(BLOCK_COLUMNS)
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
        .order('position')
      if (error) throw error
      return data
    },
  })

export const weeksQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['block-weeks', mesocycleId],
    queryFn: async (): Promise<WeekData[]> => {
      const { data, error } = await supabase
        .from('block_weeks')
        .select('block_id, week, sets, reps_min, reps_max, method, intensity_value, ref_pct')
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
      if (error) throw error
      return data.map((w) => ({
        block_id: w.block_id,
        week: w.week,
        sets: w.sets,
        repsMin: w.reps_min,
        repsMax: w.reps_max,
        method: w.method,
        value: w.intensity_value,
        refPct: w.ref_pct,
      }))
    },
  })

/** Settimane con almeno una seduta registrata: la griglia le blocca. */
export const lockedWeeksQuery = (mesocycleId: string) =>
  queryOptions({
    queryKey: ['locked-weeks', mesocycleId],
    queryFn: async (): Promise<number[]> => {
      const { data, error } = await supabase
        .from('workouts')
        .select('week')
        .eq('mesocycle_id', mesocycleId)
        .is('deleted_at', null)
      if (error) throw error
      return [...new Set(data.map((w) => w.week))].sort((a, b) => a - b)
    },
  })

export async function addBlock(args: {
  mesocycleId: string
  slotId: string
  position: number
  role?: BlockRole
}) {
  const { error } = await supabase.from('set_blocks').insert({
    mesocycle_id: args.mesocycleId,
    slot_id: args.slotId,
    position: args.position,
    role: args.role ?? 'working',
  })
  if (error) throw error
}

export type BlockPatch = Partial<
  Pick<
    BlockData,
    | 'role'
    | 'technique'
    | 'tut_eccentric_s'
    | 'tut_bottom_pause_s'
    | 'tut_concentric_s'
    | 'tut_top_pause_s'
    | 'rest_s'
    | 'prep_s'
    | 'ref_block_id'
  >
>

export async function updateBlock(mesocycleId: string, blockId: string, patch: BlockPatch) {
  const { error } = await supabase
    .from('set_blocks')
    .update(patch)
    .eq('id', blockId)
    .eq('mesocycle_id', mesocycleId)
  if (error) throw error
}

/** Eliminazione logica; i blocchi che puntavano a questo perdono il riferimento. */
export async function deleteBlock(mesocycleId: string, blockId: string) {
  const { error: refError } = await supabase
    .from('set_blocks')
    .update({ ref_block_id: null })
    .eq('mesocycle_id', mesocycleId)
    .eq('ref_block_id', blockId)
  if (refError) throw refError
  const { error } = await supabase
    .from('set_blocks')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', blockId)
    .eq('mesocycle_id', mesocycleId)
  if (error) throw error
}

/** Scrive le celle: valore pieno = upsert sulla chiave (blocco, settimana); null = eliminazione logica. */
export async function writeCells(mesocycleId: string, ops: readonly CellOp[]) {
  const upserts = ops.flatMap((o) =>
    o.value
      ? [
          {
            mesocycle_id: mesocycleId,
            block_id: o.blockId,
            week: o.week,
            sets: o.value.sets,
            reps_min: o.value.repsMin,
            reps_max: o.value.repsMax,
            method: o.value.method,
            intensity_value: o.value.value,
            ref_pct: o.value.refPct,
            deleted_at: null,
          },
        ]
      : [],
  )
  if (upserts.length > 0) {
    const { error } = await supabase.from('block_weeks').upsert(upserts, { onConflict: 'block_id,week' })
    if (error) throw error
  }
  const now = new Date().toISOString()
  const clears = await Promise.all(
    ops
      .filter((o) => !o.value)
      .map((o) =>
        supabase
          .from('block_weeks')
          .update({ deleted_at: now })
          .eq('mesocycle_id', mesocycleId)
          .eq('block_id', o.blockId)
          .eq('week', o.week),
      ),
  )
  const failed = clears.find((r) => r.error)
  if (failed?.error) throw failed.error
}

export const ROLES: readonly BlockRole[] = ['warmup', 'top', 'backoff', 'working']
export const TECHNIQUES: readonly Technique[] = ['none', 'drop', 'rest_pause', 'myo', 'cluster']

/** Applica una regola di progressione al blocco (funzione SQL); ritorna le settimane scritte. */
export async function applyProgression(blockId: string, rule: Record<string, unknown>): Promise<number> {
  const { data, error } = await supabase.rpc('generate_progression', {
    p_block_id: blockId,
    p_rule: rule as Json,
  })
  if (error) throw error
  return data
}
