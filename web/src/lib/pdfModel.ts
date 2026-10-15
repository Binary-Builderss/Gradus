import { fieldText, type Measure } from './cellFields'
import { buildGridRows, type BlockData, type GridRow, type WeekData } from './gridModel'
import { messages } from './messages'
import type { GroupRow, SlotRow } from './slots'

const m = messages.app.pdf
const block = messages.app.mesocycle.block

export type PdfCell = { main: string; sub: string }
export type PdfRow = { number: string; name: string; notes: string[]; cells: PdfCell[] }
export type PdfSession = { name: string; rows: PdfRow[] }
export type PdfModel = {
  brandName: string
  athleteName: string
  mesocycleName: string
  meta: { label: string; value: string }[]
  weeks: number
  deloadWeeks: readonly number[]
  sessions: PdfSession[]
}

const letter = (i: number) => String.fromCharCode(65 + i)

function cellText(row: GridRow, week: number): PdfCell {
  const cell = row.cells.get(week)
  if (!cell) return { main: '', sub: '' }
  // Ogni settimana si legge con la propria misura: una riga può averne di diverse.
  const measure: Measure = cell.method ?? (cell.refPct !== null ? 'REF' : 'BUF')
  const reps = fieldText(cell, 'reps', measure)
  const value = fieldText(cell, 'value', measure)
  return {
    main: reps ? m.setsReps(cell.sets, reps) : m.sets(cell.sets),
    sub: value ? m.effort[measure](value) : '',
  }
}

function notesOf(b: BlockData): string[] {
  const tempo = [b.tut_eccentric_s, b.tut_bottom_pause_s, b.tut_concentric_s, b.tut_top_pause_s]
  return [
    b.role !== 'working' ? block.roles[b.role] : '',
    b.technique !== 'none' ? block.techniques[b.technique] : '',
    b.rest_s !== null ? m.rest(b.rest_s) : '',
    tempo.every((t) => t !== null) ? m.tempo(tempo.join('-')) : '',
  ].filter(Boolean)
}

/** Programma pronto da disegnare: una tabella per seduta, esercizi numerati, una cella per settimana. */
export function buildPdfModel(args: {
  brandName: string
  athleteName: string
  mesocycle: { name: string; start_date: string; weeks: number; deload_weeks: readonly number[] }
  sessions: readonly { id: string; name: string }[]
  groups: readonly GroupRow[]
  slots: readonly SlotRow[]
  blocks: readonly BlockData[]
  weeks: readonly WeekData[]
  formatDate: (iso: string) => string
}): PdfModel {
  const { mesocycle } = args
  const sessions = args.sessions.map((s): PdfSession => {
    const groups = args.groups.filter((g) => g.session_id === s.id).sort((a, b) => a.position - b.position)
    const gridRows = buildGridRows(s.id, args.groups, args.slots, args.blocks, args.weeks)
    const rows: PdfRow[] = []
    groups.forEach((g, gi) => {
      const slots = args.slots.filter((x) => x.group_id === g.id).sort((a, b) => a.position - b.position)
      slots.forEach((slot, si) => {
        const own = gridRows.filter((r) => r.slotId === slot.id && r.block)
        own.forEach((row, bi) => {
          rows.push({
            number: bi === 0 ? `${gi + 1}${slots.length > 1 ? letter(si) : ''}` : '',
            name: bi === 0 ? slot.exercise_name : '',
            notes: notesOf(row.block!),
            cells: Array.from({ length: mesocycle.weeks }, (_, w) => cellText(row, w + 1)),
          })
        })
      })
    })
    return { name: s.name, rows }
  })
  return {
    brandName: args.brandName,
    athleteName: args.athleteName,
    mesocycleName: mesocycle.name,
    meta: [
      { label: m.athlete, value: args.athleteName },
      { label: m.mesocycle, value: mesocycle.name },
      { label: m.start, value: args.formatDate(mesocycle.start_date) },
      { label: m.duration, value: messages.app.athleteDetail.weeksCount(mesocycle.weeks) },
    ],
    weeks: mesocycle.weeks,
    deloadWeeks: mesocycle.deload_weeks,
    sessions,
  }
}

/** Nome del file: senza caratteri che i sistemi operativi non accettano. */
export const pdfFileName = (mesocycle: string, athlete: string) =>
  `${m
    .file(mesocycle, athlete)
    .replace(/[\\/:*?"<>|]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()}.pdf`
