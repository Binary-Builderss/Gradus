export type Method = 'BUF' | 'RPE' | 'RM' | 'PCT_1RM' | 'LOAD'

/** Prescrizione di un blocco in una settimana (una riga di `block_weeks`). */
export type CellValue = {
  sets: number
  repsMin: number | null
  repsMax: number | null
  method: Method | null
  value: number | null
  refPct: number | null
}

export type ParsedCell = { ok: true; value: CellValue | null } | { ok: false }

const NUM = String.raw`(\d+(?:[.,]\d+)?)`
const HEAD = new RegExp(String.raw`^(\d{1,2})\s*(?:[x×]\s*(\d{1,3})(?:\s*-\s*(\d{1,3}))?)?`, 'i')
// Ordine = indice usato in parseCell: 0 sforzo, 1 %1RM, 2 kg, 3 %ref.
const TOKENS = [
  new RegExp(`^(BUF|RPE|RM)\\s*${NUM}`, 'i'),
  new RegExp(`^${NUM}\\s*%\\s*1RM`, 'i'),
  new RegExp(`^${NUM}\\s*kg`, 'i'),
  new RegExp(`^${NUM}\\s*%\\s*ref`, 'i'),
]

const toNumber = (s: string) => Number(s.replace(',', '.'))

/**
 * Sintassi compatta di una cella: `3x8-10 BUF 2`, `4x6 RPE 8`, `5x5 80%1RM`, `3x8 60kg`, `2x10 85%ref`.
 * Vuoto = nessuna prescrizione. `%ref` è la percentuale del blocco collegato (back-off).
 */
export function parseCell(text: string): ParsedCell {
  let rest = text.trim()
  if (rest === '') return { ok: true, value: null }
  const head = HEAD.exec(rest)
  if (!head) return { ok: false }
  const cell: CellValue = {
    sets: Number(head[1]),
    repsMin: head[2] ? Number(head[2]) : null,
    repsMax: head[3] ? Number(head[3]) : head[2] ? Number(head[2]) : null,
    method: null,
    value: null,
    refPct: null,
  }
  if (cell.repsMin !== null && cell.repsMax !== null && cell.repsMin > cell.repsMax) return { ok: false }
  rest = rest.slice(head[0].length).trim()

  while (rest !== '') {
    let matched = false
    for (const [i, re] of TOKENS.entries()) {
      const m = re.exec(rest)
      if (!m) continue
      matched = true
      rest = rest.slice(m[0].length).trim()
      if (i === 3) {
        if (cell.refPct !== null) return { ok: false }
        cell.refPct = toNumber(m[1]!)
      } else {
        if (cell.method !== null) return { ok: false }
        if (i === 0) {
          cell.method = m[1]!.toUpperCase() as Method
          cell.value = toNumber(m[2]!)
        } else {
          cell.method = i === 1 ? 'PCT_1RM' : 'LOAD'
          cell.value = toNumber(m[1]!)
        }
      }
      break
    }
    if (!matched) return { ok: false }
  }
  if (cell.value !== null && cell.value > 9999) return { ok: false }
  if (cell.refPct !== null && cell.refPct > 999) return { ok: false }
  return { ok: true, value: cell }
}

const num = (n: number) => String(n).replace('.', ',')

export function formatCell(cell: CellValue | null | undefined): string {
  if (!cell) return ''
  const parts = [String(cell.sets)]
  if (cell.repsMin !== null) {
    const reps =
      cell.repsMax !== null && cell.repsMax !== cell.repsMin
        ? `${cell.repsMin}-${cell.repsMax}`
        : `${cell.repsMin}`
    parts[0] += `x${reps}`
  }
  if (cell.method && cell.value !== null) {
    parts.push(
      cell.method === 'PCT_1RM'
        ? `${num(cell.value)}%1RM`
        : cell.method === 'LOAD'
          ? `${num(cell.value)}kg`
          : `${cell.method} ${num(cell.value)}`,
    )
  }
  if (cell.refPct !== null) parts.push(`${num(cell.refPct)}%ref`)
  return parts.join(' ')
}

export function toTsv(matrix: readonly (readonly string[])[]): string {
  return matrix.map((row) => row.join('\t')).join('\n')
}

export function parseTsv(text: string): string[][] {
  const lines = text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n')
  return lines.map((l) => l.split('\t'))
}
