import { z } from 'zod'
import { messages } from './messages'

const e = messages.app.mesocycle.progression.errors

const optionalNumber = (message: string) =>
  z
    .string()
    .trim()
    .transform((v) => (v === '' ? undefined : Number(v.replace(',', '.'))))
    .refine((v) => v === undefined || Number.isFinite(v), message)

const optionalInt = (message: string, min: number, max: number) =>
  optionalNumber(message).refine(
    (v) => v === undefined || (Number.isInteger(v) && v >= min && v <= max),
    message,
  )

export const progressionSchema = z
  .object({
    setsStart: optionalInt(e.sets, 0, 99),
    setsStep: optionalNumber(e.number),
    setsMax: optionalInt(e.sets, 0, 99),
    repsMin: optionalInt(e.reps, 0, 999),
    repsMax: optionalInt(e.reps, 0, 999),
    method: z.enum(['', 'BUF', 'RPE', 'RM', 'PCT_1RM', 'LOAD']),
    intStart: optionalNumber(e.number),
    intStep: optionalNumber(e.number),
    intMin: optionalNumber(e.number),
    fromWeek: optionalInt(e.weeks, 1, 52),
    toWeek: optionalInt(e.weeks, 1, 52),
  })
  .superRefine((v, ctx) => {
    const issue = (path: string, message: string) => ctx.addIssue({ code: 'custom', path: [path], message })
    if (v.setsStart === undefined) issue('setsStart', e.setsRequired)
    if (v.repsMin !== undefined && v.repsMax !== undefined && v.repsMin > v.repsMax)
      issue('repsMax', e.repsOrder)
    if ((v.method === '') !== (v.intStart === undefined)) issue('intStart', e.methodPair)
    if (v.fromWeek !== undefined && v.toWeek !== undefined && v.fromWeek > v.toWeek)
      issue('toWeek', e.weekOrder)
  })
export type ProgressionForm = z.infer<typeof progressionSchema>

type Series = { start: number; step?: number; min?: number; max?: number }
const series = (start: number | undefined, step?: number, min?: number, max?: number): Series | undefined =>
  start === undefined
    ? undefined
    : {
        start,
        ...(step !== undefined && { step }),
        ...(min !== undefined && { min }),
        ...(max !== undefined && { max }),
      }

/** Regola jsonb per `generate_progression`: solo i campi compilati. */
export function buildRule(v: ProgressionForm): Record<string, unknown> {
  const rule = {
    sets: series(v.setsStart, v.setsStep, undefined, v.setsMax),
    reps_min: series(v.repsMin ?? v.repsMax),
    reps_max: series(v.repsMax ?? v.repsMin),
    method: v.method || undefined,
    intensity: series(v.intStart, v.intStep, v.intMin),
    from_week: v.fromWeek,
    to_week: v.toWeek,
  }
  return Object.fromEntries(Object.entries(rule).filter(([, value]) => value !== undefined))
}
