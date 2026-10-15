import { queryOptions } from '@tanstack/react-query'
import type { Json } from './database.types'
import { supabase } from './supabase'

export type ProgressionPreset = { id: string; name: string; rule: Json }

/** Modelli di progressione salvati dal coach (la regola è quella di `generate_progression`). */
export const progressionPresetsQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['progression-presets', coachId],
    queryFn: async (): Promise<ProgressionPreset[]> => {
      const { data, error } = await supabase
        .from('progression_presets')
        .select('id, name, rule')
        .eq('owner_id', coachId)
        .order('name')
      if (error) throw error
      return data
    },
  })

export async function savePreset(coachId: string, name: string, rule: Record<string, unknown>) {
  const { error } = await supabase
    .from('progression_presets')
    .insert({ owner_id: coachId, name, rule: rule as { [key: string]: Json } })
  if (error) throw error
}

export async function deletePreset(coachId: string, id: string) {
  const { error } = await supabase.from('progression_presets').delete().eq('id', id).eq('owner_id', coachId)
  if (error) throw error
}
