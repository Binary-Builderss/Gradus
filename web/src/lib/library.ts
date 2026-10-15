import { queryOptions } from '@tanstack/react-query'
import { diffMuscles, type ExerciseInput, type Muscle } from './exerciseForm'
import { supabase } from './supabase'

export type ExerciseVideo = { id: string; url: string; title: string | null }

export type LibraryExercise = {
  id: string
  name: string
  notes: string | null
  owner_id: string | null
  muscles: { muscle: Muscle; weight: number }[]
  /** Link video messi da questo coach (RLS mostra solo i suoi). */
  videos: ExerciseVideo[]
}

/** Catalogo globale e propri esercizi, con i pesi per muscolo. La chiave sta sotto ['exercises'] come il selettore. */
export const libraryQuery = (coachId: string) =>
  queryOptions({
    queryKey: ['exercises', 'library', coachId],
    queryFn: async (): Promise<LibraryExercise[]> => {
      const { data, error } = await supabase
        .from('exercises')
        .select(
          'id, name, notes, owner_id, exercise_muscles(muscle, weight), exercise_videos(id, url, title, created_at)',
        )
        .is('deleted_at', null)
        .or(`owner_id.is.null,owner_id.eq.${coachId}`)
        .order('name')
      if (error) throw error
      return data.map(({ exercise_muscles, exercise_videos, ...e }) => ({
        ...e,
        muscles: [...exercise_muscles].sort((a, b) => b.weight - a.weight),
        videos: [...exercise_videos]
          .sort((a, b) => a.created_at.localeCompare(b.created_at))
          .map(({ id, url, title }) => ({ id, url, title })),
      }))
    },
  })

export async function createExercise(coachId: string, input: ExerciseInput) {
  const { data, error } = await supabase
    .from('exercises')
    .insert({ owner_id: coachId, name: input.name, notes: input.notes })
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
    .update({ name: input.name, notes: input.notes })
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

/** Aggiunge un link video del coach a un esercizio (anche del catalogo). */
export async function addExerciseVideo(
  coachId: string,
  exerciseId: string,
  video: { url: string; title: string | null },
) {
  const { error } = await supabase
    .from('exercise_videos')
    .insert({ exercise_id: exerciseId, owner_id: coachId, url: video.url, title: video.title })
  if (error) throw error
}

export async function removeExerciseVideo(coachId: string, videoId: string) {
  const { error } = await supabase.from('exercise_videos').delete().eq('id', videoId).eq('owner_id', coachId)
  if (error) throw error
}
