import { queryOptions } from '@tanstack/react-query'
import { diffMuscles, type ExerciseInput, type Muscle } from './exerciseForm'
import { supabase } from './supabase'

export type LibraryExercise = {
  id: string
  name: string
  video_url: string | null
  notes: string | null
  owner_id: string | null
  muscles: { muscle: Muscle; weight: number }[]
}

/** Catalogo globale e propri esercizi, con i pesi per muscolo. La chiave sta sotto ['exercises'] come il selettore. */
export const libraryQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['exercises', 'library', coachId],
    queryFn: async (): Promise<LibraryExercise[]> => {
      const { data, error } = await supabase
        .from('exercises')
        .select('id, name, video_url, notes, owner_id, exercise_muscles(muscle, weight)')
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

export async function createExercise(coachId: string, input: ExerciseInput) {
  const { data, error } = await supabase
    .from('exercises')
    .insert({ owner_id: coachId, name: input.name, video_url: input.video_url, notes: input.notes })
    .select('id')
    .single()
  if (error) throw error
  const { error: muscleError } = await supabase
    .from('exercise_muscles')
    .insert(input.muscles.map((m) => ({ exercise_id: data.id, ...m })))
  if (muscleError) {
    // Niente esercizio senza muscoli: toglie quello appena creato.
    await supabase.from('exercises').update({ deleted_at: new Date().toISOString() }).eq('id', data.id)
    throw muscleError
  }
}

export async function updateExercise(
  coachId: string,
  exercise: Pick<LibraryExercise, 'id' | 'muscles'>,
  input: ExerciseInput,
) {
  const { error } = await supabase
    .from('exercises')
    .update({ name: input.name, video_url: input.video_url, notes: input.notes })
    .eq('id', exercise.id)
    .eq('owner_id', coachId)
  if (error) throw error

  const { upsert, remove } = diffMuscles(exercise.muscles, input.muscles)
  if (upsert.length > 0) {
    const { error: upsertError } = await supabase.from('exercise_muscles').upsert(
      upsert.map((m) => ({ exercise_id: exercise.id, ...m })),
      { onConflict: 'exercise_id,muscle' },
    )
    if (upsertError) throw upsertError
  }
  if (remove.length > 0) {
    const { error: removeError } = await supabase
      .from('exercise_muscles')
      .delete()
      .eq('exercise_id', exercise.id)
      .in('muscle', remove)
    if (removeError) throw removeError
  }
}

/** Eliminazione logica: le schede che usano già l'esercizio continuano a mostrarlo. */
export async function deleteExercise(coachId: string, exerciseId: string) {
  const { error } = await supabase
    .from('exercises')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', exerciseId)
    .eq('owner_id', coachId)
  if (error) throw error
}
