import { type CellValue, editField, FIELDS, fieldText, type Measure, parseTsv, toTsv } from './cellFields'
import type { GroupKind } from './slotRules'

export type BlockRole = 'warmup' | 'top' | 'backoff' | 'working'
export type Technique = 'none' | 'drop' | 'rest_pause' | 'myo' | 'cluster'

export type BlockData = {
  id: string
  slot_id: string
  position: number
  role: BlockRole
  technique: Technique
  tut_eccentric_s: number | null
  tut_bottom_pause_s: number | null
  tut_concentric_s: number | null
  tut_top_pause_s: number | null
  rest_s: number | null
  prep_s: number | null
  ref_block_id: string | null
}

export type WeekData = { block_id: string; week: number } & CellValue

/** Una riga della griglia: un blocco, oppure un esercizio ancora senza blocchi (blockId null). */
export type GridRow = {
  key: string
  blockId: string | null
  slotId: string
  exerciseName: string
  groupKind: GroupKind
  block: BlockData | null
  cells: ReadonlyMap<number, CellValue>
}

export type CellOp = { blockId: string; week: number; value: CellValue | null }

type GroupLike = { id: string; session_id: string; position: number; kind: GroupKind }
type SlotLike = { id: string; group_id: string; position: number; exercise_name: string }

/** Righe di una seduta nell'ordine gruppo → esercizio → blocco. */
export function buildGridRows(
  sessionId: string,
  groups: readonly GroupLike[],
  slots: readonly SlotLike[],
  blocks: readonly BlockData[],
  weeks: readonly WeekData[],
): GridRow[] {
  const byBlock = new Map<string, Map<number, CellValue>>()
  for (const { block_id, week, ...cell } of weeks) {
    if (!byBlock.has(block_id)) byBlock.set(block_id, new Map())
    byBlock.get(block_id)!.set(week, cell)
  }
  const byPosition = <T extends { position: number }>(a: T, b: T) => a.position - b.position
  const rows: GridRow[] = []
  for (const g of groups.filter((x) => x.session_id === sessionId).sort(byPosition)) {
    for (const s of slots.filter((x) => x.group_id === g.id).sort(byPosition)) {
      const own = blocks.filter((b) => b.slot_id === s.id).sort(byPosition)
      const base = { slotId: s.id, exerciseName: s.exercise_name, groupKind: g.kind }
      if (own.length === 0)
        rows.push({ ...base, key: `slot-${s.id}`, blockId: null, block: null, cells: new Map() })
      for (const b of own)
        rows.push({ ...base, key: b.id, blockId: b.id, block: b, cells: byBlock.get(b.id) ?? new Map() })
    }
  }
  return rows
}

/** Serie prescritte per settimana (indice 0 = settimana 1), sommando tutti i blocchi della seduta. */
export function weekSetTotals(rows: readonly GridRow[], totalWeeks: number): number[] {
  return Array.from({ length: totalWeeks }, (_, i) =>
    rows.reduce((sum, row) => sum + (row.cells.get(i + 1)?.sets ?? 0), 0),
  )
}

/** Copia la settimana `from` sulle successive (blocchi con prescrizione), saltando le settimane bloccate. */
export function copyForwardOps(
  rows: readonly GridRow[],
  from: number,
  totalWeeks: number,
  locked: ReadonlySet<number>,
): CellOp[] {
  const ops: CellOp[] = []
  for (const row of rows) {
    const source = row.cells.get(from)
    if (!row.blockId || !source) continue
    for (let week = from + 1; week <= totalWeeks; week++)
      if (!locked.has(week)) ops.push({ blockId: row.blockId, week, value: source })
  }
  return ops
}

/** Una colonna per campo: la settimana w (da 1) occupa le colonne (w-1)·3 … (w-1)·3 + 2. */
export const weekOfColumn = (c: number) => Math.floor(c / FIELDS.length) + 1

export type Range = { r1: number; c1: number; r2: number; c2: number }

export const normalizeRange = (a: { r: number; c: number }, b: { r: number; c: number }): Range => ({
  r1: Math.min(a.r, b.r),
  c1: Math.min(a.c, b.c),
  r2: Math.max(a.r, b.r),
  c2: Math.max(a.c, b.c),
})

type RowMeasure = (row: GridRow) => Measure

/** TSV dei campi nell'intervallo, nello stesso ordine della griglia. */
export function rangeToTsv(rows: readonly GridRow[], range: Range, measureOf: RowMeasure): string {
  const matrix: string[][] = []
  for (let r = range.r1; r <= range.r2; r++) {
    const row = rows[r]
    const line: string[] = []
    for (let c = range.c1; c <= range.c2; c++)
      line.push(
        row ? fieldText(row.cells.get(weekOfColumn(c)), FIELDS[c % FIELDS.length]!, measureOf(row)) : '',
      )
    matrix.push(line)
  }
  return toTsv(matrix)
}

export type FieldEdit = { r: number; c: number; text: string }

/**
 * Applica più scritture di campo, anche sulla stessa settimana, e le raccoglie in una sola operazione
 * per settimana. Campi fuori griglia, su righe senza blocco o su settimane bloccate sono saltati;
 * testo non valido è contato, non scritto.
 */
export function applyEdits(
  rows: readonly GridRow[],
  edits: readonly FieldEdit[],
  totalWeeks: number,
  locked: ReadonlySet<number>,
  measureOf: RowMeasure,
): { ops: CellOp[]; invalid: number; skipped: number } {
  const working = new Map<
    string,
    { blockId: string; week: number; cell: CellValue | null; existed: boolean }
  >()
  let invalid = 0
  let skipped = 0
  for (const { r, c, text } of edits) {
    const row = rows[r]
    const week = weekOfColumn(c)
    if (!row?.blockId || week > totalWeeks || locked.has(week)) {
      skipped++
      continue
    }
    const key = `${row.blockId}:${week}`
    const current = working.has(key) ? working.get(key)!.cell : (row.cells.get(week) ?? null)
    const result = editField(current ?? undefined, FIELDS[c % FIELDS.length]!, text, measureOf(row))
    if (!result.ok) invalid++
    else working.set(key, { blockId: row.blockId, week, cell: result.cell, existed: row.cells.has(week) })
  }
  const ops = [...working.values()]
    .filter((w) => w.cell !== null || w.existed)
    .map((w): CellOp => ({ blockId: w.blockId, week: w.week, value: w.cell }))
  return { ops, invalid, skipped }
}

/** Incolla una tabella TSV (un campo per colonna) a partire da (riga, colonna). */
export function pasteOps(
  rows: readonly GridRow[],
  anchor: { r: number; c: number },
  tsv: string,
  totalWeeks: number,
  locked: ReadonlySet<number>,
  measureOf: RowMeasure,
) {
  const edits = parseTsv(tsv).flatMap((line, dr) =>
    line.map((text, dc): FieldEdit => ({ r: anchor.r + dr, c: anchor.c + dc, text })),
  )
  return applyEdits(rows, edits, totalWeeks, locked, measureOf)
}

/** Svuota i campi dell'intervallo (Canc): le serie vuote tolgono tutta la settimana. */
export function clearOps(
  rows: readonly GridRow[],
  range: Range,
  totalWeeks: number,
  locked: ReadonlySet<number>,
  measureOf: RowMeasure,
) {
  const edits: FieldEdit[] = []
  for (let r = range.r1; r <= range.r2; r++)
    for (let c = range.c1; c <= range.c2; c++) edits.push({ r, c, text: '' })
  return applyEdits(rows, edits, totalWeeks, locked, measureOf).ops
}
