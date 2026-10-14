import { z } from 'zod'
import { messages } from './messages'

const e = messages.app.mesocycle.errors

export const newMesocycleSchema = z.object({
  name: z.string().trim().min(1, e.nameRequired),
  start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, e.dateRequired),
  weeks: z.coerce.number(e.weeksRange).int(e.weeksRange).min(1, e.weeksRange).max(52, e.weeksRange),
})

/** Aggiunge o toglie `week` dalle settimane di scarico (ordinate, solo 1..weeks). */
export function toggleDeload(deload: readonly number[], week: number, weeks: number): number[] {
  if (week < 1 || week > weeks) return clampDeload(deload, weeks)
  const next = deload.includes(week) ? deload.filter((w) => w !== week) : [...deload, week]
  return clampDeload(next, weeks)
}

/** Scarichi validi per un mesociclo di `weeks` settimane: nessuna oltre la durata, senza doppioni. */
export function clampDeload(deload: readonly number[], weeks: number): number[] {
  return [...new Set(deload)].filter((w) => w >= 1 && w <= weeks).sort((a, b) => a - b)
}

/** Prossima posizione in coda a una lista ordinata per `position`. */
export function nextPosition(items: readonly { position: number }[]): number {
  return items.reduce((max, i) => Math.max(max, i.position + 1), 0)
}
