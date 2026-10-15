import { ArrowLineRightIcon, CaretDownIcon, LockSimpleIcon, PlusIcon } from '@phosphor-icons/react'
import { createColumnHelper, getCoreRowModel, useReactTable } from '@tanstack/react-table'
import { Fragment, useMemo, useRef, useState, type ClipboardEvent, type KeyboardEvent } from 'react'
import { BlockDetails } from '@/components/mesocycles/BlockDetails'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { Collapsible } from '@/components/ui/collapsible'
import { addBlock, writeCells } from '@/lib/blocks'
import {
  changeMeasure,
  describeCell,
  editField,
  type Field,
  FIELDS,
  fieldText,
  type Measure,
  MEASURES,
  measureOf,
} from '@/lib/cellFields'
import {
  type CellOp,
  clearOps,
  copyForwardOps,
  type GridRow,
  normalizeRange,
  pasteOps,
  type Range,
  rangeToTsv,
  weekOfColumn,
  weekSetTotals,
} from '@/lib/gridModel'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle
type Pos = { r: number; c: number }

const col = createColumnHelper<GridRow>()

// Larghezza dei tre campi di una settimana: serie, ripetizioni, sforzo.
const fieldWidth: Record<Field, string> = { sets: 'w-10', reps: 'w-14', value: 'w-14' }

export function SessionGrid({
  mesocycleId,
  rows,
  totalWeeks,
  deloadWeeks,
  lockedWeeks,
}: {
  mesocycleId: string
  rows: GridRow[]
  totalWeeks: number
  deloadWeeks: readonly number[]
  lockedWeeks: ReadonlySet<number>
}) {
  const tableRef = useRef<HTMLTableElement>(null)
  const [active, setActive] = useState<Pos>({ r: 0, c: 0 })
  const [anchor, setAnchor] = useState<Pos>({ r: 0, c: 0 })
  const [expanded, setExpanded] = useState<string | null>(null)
  const [note, setNote] = useState('')
  const [hasFocus, setHasFocus] = useState(false)
  // Misura scelta per le righe ancora senza prescrizioni: poi la deducono dalle celle scritte.
  const [picked, setPicked] = useState<ReadonlyMap<string, Measure>>(new Map())
  const extending = useRef(false)

  const keys = [
    ['block-weeks', mesocycleId],
    ['blocks', mesocycleId],
  ]
  const write = useEditorMutation((ops: CellOp[]) => writeCells(mesocycleId, ops), keys)
  const create = useEditorMutation(
    (v: { slotId: string; position: number }) => addBlock({ mesocycleId, ...v }),
    keys,
  )

  const rowMeasure = (row: GridRow): Measure => picked.get(row.key) ?? measureOf(row.cells.values())
  const range: Range = normalizeRange(anchor, active)
  const multi = range.r1 !== range.r2 || range.c1 !== range.c2
  const totalCols = totalWeeks * FIELDS.length
  const weekNumbers = Array.from({ length: totalWeeks }, (_, i) => i + 1)
  const totals = weekSetTotals(rows, totalWeeks)
  const activeRow = hasFocus ? rows[active.r] : undefined
  const activeWeek = activeRow ? weekOfColumn(active.c) : null

  const columns = useMemo(
    () => [
      col.display({ id: 'label' }),
      ...Array.from({ length: totalWeeks }, (_, i) => col.display({ id: `w${i + 1}` })),
    ],
    [totalWeeks],
  )
  const table = useReactTable({ data: rows, columns, getCoreRowModel: getCoreRowModel() })

  function focusCell(r: number, c: number, extend: boolean) {
    const rr = Math.max(0, Math.min(rows.length - 1, r))
    const cc = Math.max(0, Math.min(totalCols - 1, c))
    const input = tableRef.current?.querySelector<HTMLInputElement>(`[data-r="${rr}"][data-c="${cc}"]`)
    if (!input) return
    extending.current = extend
    input.focus()
    extending.current = false
    input.select()
  }

  function onKeyDown(e: KeyboardEvent<HTMLTableElement>) {
    const input = e.target as HTMLInputElement
    if (input.dataset.r === undefined) return
    const r = Number(input.dataset.r)
    const c = Number(input.dataset.c)
    const atStart = input.selectionStart === 0 && input.selectionEnd === 0
    const atEnd = input.selectionStart === input.value.length && input.selectionEnd === input.value.length
    const extend = e.shiftKey
    const go = (dr: number, dc: number) => {
      e.preventDefault()
      focusCell(r + dr, c + dc, extend)
    }
    if (e.key === 'ArrowDown' || (e.key === 'Enter' && !e.shiftKey)) go(1, 0)
    else if (e.key === 'ArrowUp' || (e.key === 'Enter' && e.shiftKey)) go(-1, 0)
    else if (e.key === 'ArrowRight' && (atEnd || extend)) go(0, 1)
    else if (e.key === 'ArrowLeft' && (atStart || extend)) go(0, -1)
    else if ((e.key === 'Delete' || e.key === 'Backspace') && multi) {
      e.preventDefault()
      const ops = clearOps(rows, range, totalWeeks, lockedWeeks, rowMeasure)
      if (ops.length > 0) write.mutate(ops)
    }
  }

  function onCopy(e: ClipboardEvent<HTMLTableElement>) {
    if (!multi) return
    e.preventDefault()
    e.clipboardData.setData('text/plain', rangeToTsv(rows, range, rowMeasure))
  }

  function onPaste(e: ClipboardEvent<HTMLTableElement>) {
    const text = e.clipboardData.getData('text/plain')
    if (!/[\t\n]/.test(text.trim())) return // un solo valore: incolla normale nel campo
    e.preventDefault()
    const result = pasteOps(rows, { r: range.r1, c: range.c1 }, text, totalWeeks, lockedWeeks, rowMeasure)
    setNote(m.grid.pasteReport(result.invalid, result.skipped))
    if (result.ops.length > 0) write.mutate(result.ops)
  }

  function changeRowMeasure(row: GridRow, to: Measure) {
    const from = rowMeasure(row)
    setPicked(new Map(picked).set(row.key, to))
    if (!row.blockId) return
    const ops: CellOp[] = [...row.cells].map(([week, cell]) => ({
      blockId: row.blockId!,
      week,
      value: changeMeasure(cell, from, to),
    }))
    if (ops.length > 0) write.mutate(ops)
  }

  const activeCell = activeRow && activeWeek ? activeRow.cells.get(activeWeek) : undefined

  return (
    <div className="grid gap-2">
      <div className="grid gap-2" data-tour="grid">
        <div
          className="flex min-h-9 flex-wrap items-center gap-x-3 gap-y-1 rounded-md border bg-card px-3 py-1.5 text-sm"
          aria-live="polite"
        >
          {activeRow?.block && activeWeek ? (
            <>
              <span className="text-muted-foreground">
                {m.grid.activeCell(activeRow.exerciseName, m.block.roles[activeRow.block.role], activeWeek)}
              </span>
              <span className="font-medium">
                {activeCell ? describeCell(activeCell, rowMeasure(activeRow)) : '–'}
              </span>
            </>
          ) : (
            <span className="text-muted-foreground">{m.grid.pickCell}</span>
          )}
        </div>
        <div className="overflow-x-auto rounded-md border bg-card">
          <table
            ref={tableRef}
            onFocus={() => setHasFocus(true)}
            onBlur={(e) => {
              if (!e.currentTarget.contains(e.relatedTarget)) setHasFocus(false)
            }}
            onKeyDown={onKeyDown}
            onCopy={onCopy}
            onPaste={onPaste}
            className="w-full border-collapse text-sm"
          >
            <thead>
              <tr className="bg-muted/50">
                <th
                  scope="col"
                  rowSpan={2}
                  className="sticky left-0 z-[1] min-w-52 border-r border-b bg-muted px-3 py-1.5 text-left text-xs font-medium text-muted-foreground"
                >
                  {m.grid.exercise}
                </th>
                {weekNumbers.map((week) => (
                  <th
                    key={week}
                    scope="colgroup"
                    colSpan={FIELDS.length}
                    className={cn(
                      'border-r px-2 py-1 text-center font-mono text-xs font-medium text-muted-foreground',
                      deloadWeeks.includes(week) && 'bg-warning text-warning-foreground',
                      week === activeWeek && 'bg-accent text-accent-foreground',
                    )}
                  >
                    <span className="inline-flex items-center gap-1">
                      {m.weekShort(week)}
                      {lockedWeeks.has(week) && (
                        <LockSimpleIcon
                          size={14}
                          aria-label={m.grid.locked}
                          className="text-muted-foreground"
                        />
                      )}
                      {week < totalWeeks && !lockedWeeks.has(week) && (
                        <Button
                          variant="ghost"
                          size="icon-xs"
                          aria-label={m.grid.copyForward(week)}
                          title={m.grid.copyForward(week)}
                          onClick={() => {
                            const ops = copyForwardOps(rows, week, totalWeeks, lockedWeeks)
                            if (ops.length > 0) write.mutate(ops)
                          }}
                        >
                          <ArrowLineRightIcon />
                        </Button>
                      )}
                    </span>
                    <span className="block font-sans text-xs font-normal">
                      {lockedWeeks.has(week)
                        ? m.grid.weekState.locked
                        : deloadWeeks.includes(week)
                          ? m.grid.weekState.deload
                          : ' '}
                    </span>
                  </th>
                ))}
              </tr>
              <tr className="border-b bg-muted/50">
                {weekNumbers.flatMap((week) =>
                  FIELDS.map((field, f) => (
                    <th
                      key={`${week}-${field}`}
                      scope="col"
                      className={cn(
                        'px-1 pb-1 text-center text-xs font-normal text-muted-foreground',
                        f === FIELDS.length - 1 && 'border-r',
                        week === activeWeek && 'bg-accent/60',
                      )}
                    >
                      {m.grid.fields[field]}
                    </th>
                  )),
                )}
              </tr>
            </thead>
            <tbody>
              {table.getRowModel().rows.map((tr, r) => {
                const row = tr.original
                const firstOfSlot = r === 0 || rows[r - 1]!.slotId !== row.slotId
                const open = expanded === row.key
                const measure = rowMeasure(row)
                const siblings = rows
                  .filter((x) => x.slotId === row.slotId && x.blockId && x.blockId !== row.blockId)
                  .map((x) => ({
                    id: x.blockId!,
                    label: `${messages.app.mesocycle.block.roles[x.block!.role]} ${x.block!.position + 1}`,
                  }))
                const rowLocked = [...row.cells.keys()].some((week) => lockedWeeks.has(week))
                return (
                  <Fragment key={row.key}>
                    <tr
                      className={cn(
                        'border-b last:border-b-0',
                        firstOfSlot && r > 0 && 'border-t border-t-foreground/20',
                      )}
                    >
                      <th
                        scope="row"
                        className={cn(
                          'sticky left-0 z-[1] border-r bg-card px-3 py-1.5 text-left font-normal',
                          r === active.r && hasFocus && 'bg-accent',
                        )}
                      >
                        <div className="flex items-center gap-2">
                          <div className="min-w-0 flex-1">
                            {firstOfSlot && <p className="truncate font-medium">{row.exerciseName}</p>}
                            {row.block ? (
                              <div className="mt-0.5 grid gap-1">
                                <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                                  <span className="rounded border bg-background px-1.5 py-px">
                                    {m.block.roles[row.block.role]}
                                  </span>
                                  {row.block.technique !== 'none' && (
                                    <span className="truncate">
                                      {m.block.techniques[row.block.technique]}
                                    </span>
                                  )}
                                </p>
                                <select
                                  aria-label={`${m.grid.measure}: ${row.exerciseName}`}
                                  title={rowLocked ? m.grid.locked : m.grid.measure}
                                  value={measure}
                                  disabled={rowLocked}
                                  onChange={(e) => changeRowMeasure(row, e.target.value as Measure)}
                                  className="h-6 w-full max-w-44 rounded border border-input bg-background px-1 text-xs text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-60"
                                >
                                  {MEASURES.map((x) => (
                                    <option key={x} value={x}>
                                      {m.grid.measures[x]}
                                    </option>
                                  ))}
                                </select>
                              </div>
                            ) : (
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => create.mutate({ slotId: row.slotId, position: 0 })}
                              >
                                <PlusIcon data-icon="inline-start" />
                                {m.grid.addBlock}
                              </Button>
                            )}
                          </div>
                          {row.block && (
                            <>
                              <Button
                                variant="ghost"
                                size="icon-xs"
                                aria-label={m.grid.addBlock}
                                title={m.grid.addBlock}
                                onClick={() =>
                                  create.mutate({
                                    slotId: row.slotId,
                                    position: Math.max(
                                      ...rows
                                        .filter((x) => x.slotId === row.slotId)
                                        .map((x) => (x.block?.position ?? -1) + 1),
                                    ),
                                  })
                                }
                              >
                                <PlusIcon />
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon-xs"
                                aria-label={m.grid.details}
                                aria-expanded={open}
                                title={m.grid.details}
                                onClick={() => setExpanded(open ? null : row.key)}
                              >
                                <CaretDownIcon className={cn('transition-transform', open && 'rotate-180')} />
                              </Button>
                            </>
                          )}
                        </div>
                      </th>
                      {weekNumbers.flatMap((week) =>
                        FIELDS.map((field, f) => {
                          const c = (week - 1) * FIELDS.length + f
                          return (
                            <td
                              key={`${week}-${field}`}
                              className={cn(
                                'p-0',
                                f === FIELDS.length - 1 && 'border-r',
                                deloadWeeks.includes(week) && 'bg-warning/60',
                                lockedWeeks.has(week) && 'bg-hatch',
                                week === activeWeek && 'bg-accent/40',
                              )}
                            >
                              {row.blockId ? (
                                <FieldInput
                                  r={r}
                                  c={c}
                                  width={fieldWidth[field]}
                                  label={m.grid.field(row.exerciseName, week, m.grid.fieldNames[field])}
                                  text={fieldText(row.cells.get(week), field, measure)}
                                  placeholder={
                                    field === 'value'
                                      ? m.grid.measureShort[measure]
                                      : m.grid.fieldPlaceholders[field]
                                  }
                                  locked={lockedWeeks.has(week)}
                                  selected={
                                    multi && r >= range.r1 && r <= range.r2 && c >= range.c1 && c <= range.c2
                                  }
                                  onFocus={() => {
                                    setActive({ r, c })
                                    if (!extending.current) setAnchor({ r, c })
                                  }}
                                  onShiftClick={() => setActive({ r, c })}
                                  onCommit={(text) => {
                                    const result = editField(row.cells.get(week), field, text, measure)
                                    if (!result.ok) return false
                                    write.mutate([{ blockId: row.blockId!, week, value: result.cell }])
                                    return true
                                  }}
                                />
                              ) : null}
                            </td>
                          )
                        }),
                      )}
                    </tr>
                    {open && row.block && (
                      <tr className="border-b bg-muted/30">
                        <td colSpan={totalCols + 1} className="p-0">
                          <BlockDetails mesocycleId={mesocycleId} block={row.block} siblings={siblings} />
                        </td>
                      </tr>
                    )}
                  </Fragment>
                )
              })}
            </tbody>
            <tfoot>
              <tr className="border-t bg-muted/50">
                <th
                  scope="row"
                  className="sticky left-0 z-[1] border-r bg-muted px-3 py-1.5 text-left text-xs font-medium text-muted-foreground"
                >
                  {m.grid.totals}
                </th>
                {weekNumbers.map((week) => (
                  <td
                    key={week}
                    colSpan={FIELDS.length}
                    className="border-r px-2 py-1.5 text-center font-mono text-xs tabular-nums"
                  >
                    {totals[week - 1] || ''}
                  </td>
                ))}
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      <p className="text-xs text-muted-foreground empty:hidden" aria-live="polite">
        {note}
      </p>
      <Collapsible title={m.grid.fillTitle} className="text-muted-foreground" data-tour="fill-help">
        <ul className="grid list-disc gap-1.5 pl-4 text-xs">
          {m.grid.fillSteps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ul>
      </Collapsible>
    </div>
  )
}

function FieldInput({
  r,
  c,
  width,
  label,
  text,
  placeholder,
  locked,
  selected,
  onFocus,
  onShiftClick,
  onCommit,
}: {
  r: number
  c: number
  width: string
  label: string
  text: string
  placeholder: string
  locked: boolean
  selected: boolean
  onFocus: () => void
  onShiftClick: () => void
  onCommit: (text: string) => boolean
}) {
  const [draft, setDraft] = useState(text)
  const [invalid, setInvalid] = useState(false)
  const [prev, setPrev] = useState(text)
  // Il valore salvato cambia (altro campo, incolla, copia): la bozza si riallinea.
  if (prev !== text) {
    setPrev(text)
    setDraft(text)
    setInvalid(false)
  }

  function commit() {
    if (draft.trim() === text) return setInvalid(false)
    setInvalid(!onCommit(draft))
  }

  return (
    <input
      data-r={r}
      data-c={c}
      aria-label={label}
      aria-invalid={invalid || undefined}
      title={invalid ? m.grid.invalid : locked ? m.grid.locked : undefined}
      readOnly={locked}
      value={draft}
      placeholder={placeholder}
      onChange={(e) => setDraft(e.target.value)}
      onFocus={onFocus}
      onMouseDown={(e) => {
        if (!e.shiftKey) return
        e.preventDefault() // Maiusc+clic estende la selezione senza spostare il focus
        onShiftClick()
      }}
      onBlur={commit}
      onKeyDown={(e) => {
        if (e.key === 'Escape') {
          setDraft(text)
          setInvalid(false)
        }
      }}
      className={cn(
        'h-9 bg-transparent px-1 text-center font-mono text-sm tabular-nums outline-none placeholder:text-transparent focus:bg-accent focus:ring-2 focus:ring-ring focus:ring-inset focus:placeholder:text-muted-foreground/60',
        width,
        selected && 'bg-accent/40',
        locked && 'cursor-not-allowed text-muted-foreground',
        invalid && 'bg-destructive/10 ring-2 ring-destructive ring-inset',
      )}
    />
  )
}
