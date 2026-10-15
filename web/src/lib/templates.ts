import { queryOptions } from '@tanstack/react-query'
import { supabase } from './supabase'

export type Template = {
  id: string
  name: string
  description: string | null
  weeks: number
  sessions: number
  created_at: string
}

/** Template del coach: copie della programmazione di un mesociclo (funzioni SQL `save_mesocycle_as_template` e `instantiate_template`). */
export const templatesQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['templates', coachId],
    queryFn: async (): Promise<Template[]> => {
      const { data, error } = await supabase
        .from('mesocycle_templates')
        .select('id, name, description, weeks, sessions, created_at')
        .eq('owner_id', coachId)
        .order('name')
      if (error) throw error
      return data
    },
  })

export async function saveAsTemplate(
  mesocycleId: string,
  values: { name: string; description: string | null },
): Promise<string> {
  const { data, error } = await supabase.rpc('save_mesocycle_as_template', {
    p_mesocycle_id: mesocycleId,
    p_name: values.name,
    p_description: values.description ?? undefined,
  })
  if (error) throw error
  return data
}

/** Nuova bozza per un atleta, copiata dal template. Ritorna l'id del mesociclo. */
export async function createFromTemplate(
  templateId: string,
  athleteId: string,
  values: { start_date: string; name: string },
): Promise<string> {
  const { data, error } = await supabase.rpc('instantiate_template', {
    p_template_id: templateId,
    p_athlete_id: athleteId,
    p_start_date: values.start_date,
    p_name: values.name || undefined,
  })
  if (error) throw error
  return data
}

export async function renameTemplate(coachId: string, id: string, name: string) {
  const { error } = await supabase
    .from('mesocycle_templates')
    .update({ name })
    .eq('id', id)
    .eq('owner_id', coachId)
  if (error) throw error
}

export async function deleteTemplate(coachId: string, id: string) {
  const { error } = await supabase.from('mesocycle_templates').delete().eq('id', id).eq('owner_id', coachId)
  if (error) throw error
}
