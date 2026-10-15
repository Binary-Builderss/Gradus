import { messages } from './messages'

const m = messages.app.mesocycle.block

/** Secondi per fase di una ripetizione: discesa, fermo in basso, salita, fermo in alto. Vuoto = non indicato. */
export type Tempo = {
  tut_eccentric_s: number | null
  tut_bottom_pause_s: number | null
  tut_concentric_s: number | null
  tut_top_pause_s: number | null
}

export const NO_TEMPO: Tempo = {
  tut_eccentric_s: null,
  tut_bottom_pause_s: null,
  tut_concentric_s: null,
  tut_top_pause_s: null,
}

const phases = (t: Tempo) =>
  [t.tut_eccentric_s, t.tut_bottom_pause_s, t.tut_concentric_s, t.tut_top_pause_s] as const

/** Notazione da palestra: discesa-fermo in basso-salita-fermo in alto, «3-1-1-0». Null se non c'è nessun tempo. */
export function tempoNotation(t: Tempo): string | null {
  const values = phases(t)
  return values.every((v) => v === null) ? null : values.map((v) => v ?? 0).join('-')
}

/** Durata di una ripetizione (le fasi non indicate contano zero). */
export const repSeconds = (t: Tempo): number => phases(t).reduce<number>((sum, v) => sum + (v ?? 0), 0)

/** «3-1-1-0: 3 s in discesa, 1 s fermo in basso, 1 s in salita, 0 s fermo in alto. 5 s a ripetizione.» */
export function describeTempo(t: Tempo): string {
  const notation = tempoNotation(t)
  if (!notation) return m.tempo.none
  const [down, bottom, up, top] = phases(t).map((v) => v ?? 0) as [number, number, number, number]
  return m.tempo.sentence(notation, down, bottom, up, top, repSeconds(t))
}

/** 45 → «45 s», 120 → «2 min», 90 → «1 min 30 s». */
export function formatSeconds(s: number): string {
  if (s < 60) return `${s} s`
  const minutes = Math.floor(s / 60)
  const rest = s % 60
  return rest === 0 ? `${minutes} min` : `${minutes} min ${rest} s`
}
