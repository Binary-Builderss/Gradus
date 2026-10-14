import { z } from 'zod'
import { messages } from './messages'

const e = messages.app.exercises.errors

export const MUSCLES = [
  'chest',
  'lats',
  'upper_back',
  'traps',
  'front_delts',
  'side_delts',
  'rear_delts',
  'biceps',
  'triceps',
  'forearms',
  'abs',
  'lower_back',
  'glutes',
  'quads',
  'hamstrings',
  'adductors',
  'abductors',
  'calves',
] as const
export type Muscle = (typeof MUSCLES)[number]

const muscleWeight = z.object({
  muscle: z.enum(MUSCLES),
  weight: z.number(e.weightRange).gt(0, e.weightRange).max(1, e.weightRange),
})

/** Video solo http(s): il link viene mostrato all'atleta, niente schemi come `javascript:`. */
const videoUrl = z
  .string()
  .trim()
  .refine((v) => v === '' || /^https?:\/\/\S+$/i.test(v), e.videoInvalid)
  .transform((v) => (v === '' ? null : v))

export const exerciseSchema = z.object({
  name: z.string().trim().min(1, e.nameRequired).max(120, e.nameTooLong),
  video_url: videoUrl,
  notes: z
    .string()
    .trim()
    .transform((v) => (v === '' ? null : v)),
  muscles: z
    .array(muscleWeight)
    .min(1, e.musclesRequired)
    .refine((list) => new Set(list.map((m) => m.muscle)).size === list.length, e.musclesDuplicate),
})
export type ExerciseInput = z.infer<typeof exerciseSchema>

/** Differenze tra i muscoli salvati e quelli del form: cosa scrivere e cosa togliere. */
export function diffMuscles(
  saved: readonly { muscle: Muscle; weight: number }[],
  next: readonly { muscle: Muscle; weight: number }[],
) {
  const old = new Map(saved.map((m) => [m.muscle, m.weight]))
  const nextSet = new Set(next.map((m) => m.muscle))
  return {
    upsert: next.filter((m) => old.get(m.muscle) !== m.weight),
    remove: saved.filter((m) => !nextSet.has(m.muscle)).map((m) => m.muscle),
  }
}
