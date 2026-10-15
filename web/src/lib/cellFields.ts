import { messages } from './messages'

export type Method = 'BUF' | 'RPE' | 'RM' | 'PCT_1RM' | 'LOAD'
/** Come si misura lo sforzo di una riga. `REF` = percentuale del carico della serie collegata (back-off). */
export type Measure = Method | 'REF'
export type Field = 'sets' | 'reps' | 'value'

export const FIELDS: readonly Field[] = ['sets', 'reps', 'value']
export const MEASURES: readonly Measure[] = ['BUF', 'RPE', 'LOAD', 'PCT_1RM', 'RM', 'REF']

/** Prescrizione di un blocco in una settimana (una riga di `block_weeks`). */
export type CellValue = {
  sets: number
  repsMin: number | null
  repsMax: number | null
  method: Method | null
  value: number | null
  refPct: number | null
}

export type EditResult = { ok: true; cell: CellValue | null } | { ok: false }

const EMPTY: CellValue = { sets: 1, repsMin: null, repsMax: null, method: null, value: null, refPct: null }
const NUMBER = /^\d+(?:[.,]\d+)?$/
const REPS = /^(\d{1,3})(?:\s*-\s*(\d{1,3}))?$/

const toNumber = (s: string) => Number(s.replace(',', '.'))
const num = (n: number) => String(n).replace('.', ',')

/** Misura di una riga: quella già scritta nelle sue settimane, altrimenti BUF. */
export function measureOf(cells: Iterable<CellValue>): Measure {
  let ref = false
  for (const c of cells) {
    if (c.method) return c.method
    if (c.refPct !== null) ref = true
  }
  return ref ? 'REF' : 'BUF'
}

export function fieldText(cell: CellValue | undefined, field: Field, measure: Measure): string {
  if (!cell) return ''
  if (field === 'sets') return String(cell.sets)
  if (field === 'reps') {
    if (cell.repsMin === null) return ''
    return cell.repsMax !== null && cell.repsMax !== cell.repsMin
      ? `${cell.repsMin}-${cell.repsMax}`
      : `${cell.repsMin}`
  }
  if (measure === 'REF') return cell.refPct === null ? '' : num(cell.refPct)
  return cell.method === measure && cell.value !== null ? num(cell.value) : ''
}

const maxFor = (measure: Measure) =>
  measure === 'BUF' || measure === 'RPE' ? 10 : measure === 'REF' ? 999 : 9999

/**
 * Applica il testo scritto in un campo a una settimana. Vuoto nelle serie = nessuna prescrizione;
 * ripetizioni e sforzo richiedono che le serie ci siano già.
 */
export function editField(
  cell: CellValue | undefined,
  field: Field,
  text: string,
  measure: Measure,
): EditResult {
  const t = text.trim()
  if (field === 'sets') {
    if (t === '') return { ok: true, cell: null }
    const sets = /^\d{1,2}$/.test(t) ? Number(t) : 0
    return sets >= 1 ? { ok: true, cell: { ...(cell ?? EMPTY), sets } } : { ok: false }
  }
  if (t === '') {
    if (!cell) return { ok: true, cell: null }
    if (field === 'reps') return { ok: true, cell: { ...cell, repsMin: null, repsMax: null } }
    return {
      ok: true,
      cell: measure === 'REF' ? { ...cell, refPct: null } : { ...cell, method: null, value: null },
    }
  }
  if (!cell) return { ok: false }
  if (field === 'reps') {
    const m = REPS.exec(t)
    if (!m) return { ok: false }
    const min = Number(m[1])
    const max = m[2] ? Number(m[2]) : min
    return min <= max ? { ok: true, cell: { ...cell, repsMin: min, repsMax: max } } : { ok: false }
  }
  if (!NUMBER.test(t) || toNumber(t) > maxFor(measure)) return { ok: false }
  const n = toNumber(t)
  return {
    ok: true,
    cell: measure === 'REF' ? { ...cell, refPct: n } : { ...cell, method: measure, value: n },
  }
}

/** Cambia la misura di una settimana tenendo il numero quando ha senso nella nuova misura. */
export function changeMeasure(cell: CellValue, from: Measure, to: Measure): CellValue {
  if (from === to) return cell
  const n = from === 'REF' ? cell.refPct : cell.value
  const base = { ...cell, method: null, value: null, refPct: from === 'REF' ? null : cell.refPct }
  if (n === null) return base
  if (to === 'REF') return { ...base, refPct: n }
  return n <= maxFor(to) ? { ...base, method: to, value: n } : base
}

const summary = messages.app.mesocycle.grid.summary

/** La prescrizione a parole, per la barra sopra la griglia: «3 serie da 8-10 ripetizioni, 2 ripetizioni in riserva». */
export function describeCell(cell: CellValue, measure: Measure): string {
  const reps = fieldText(cell, 'reps', measure)
  const value = fieldText(cell, 'value', measure)
  const head = reps ? `${summary.sets(cell.sets)} ${summary.reps(reps)}` : summary.sets(cell.sets)
  return value ? `${head}, ${summary[measure](value)}` : head
}

export function toTsv(matrix: readonly (readonly string[])[]): string {
  return matrix.map((row) => row.join('\t')).join('\n')
}

export function parseTsv(text: string): string[][] {
  const lines = text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n')
  return lines.map((l) => l.split('\t'))
}
