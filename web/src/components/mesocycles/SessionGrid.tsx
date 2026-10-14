import { ArrowLineRightIcon, CaretDownIcon, LockSimpleIcon, PlusIcon } from '@phosphor-icons/react'
import { createColumnHelper, flexRender, getCoreRowModel, useReactTable } from '@tanstack/react-table'
import { Fragment, useMemo, useRef, useState, type ClipboardEvent, type KeyboardEvent } from 'react'
import { BlockDetails } from '@/components/mesocycles/BlockDetails'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { addBlock, writeCells } from '@/lib/blocks'
import { formatCell, parseCell } from '@/lib/cellSyntax'
import {
  type CellOp,
  copyForwardOps,
  type GridRow,
  normalizeRange,
  pasteOps,
  type Range,
  rangeToTsv,
} from '@/lib/gridModel'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle
type Pos = { r: number; c: number }

const col = createColumnHelper<GridRow>()

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

  const range: Range = normalizeRange(anchor, active)
  const multi = range.r1 !== range.r2 || range.c1 !== range.c2
  const weekNumbers = Array.from({ length: totalWeeks }, (_, i) => i + 1)

  const columns = useMemo(
    () => [
      col.display({ id: 'label', header: m.grid.exercise }),
      ...Array.from({ length: totalWeeks }, (_, i) =>
        col.display({ id: `w${i + 1}`, header: String(i + 1) }),
      ),
    ],
    [totalWeeks],
  )
  const table = useReactTable({ data: rows, columns, getCoreRowModel: getCoreRowModel() })

  function focusCell(r: number, c: number, extend: boolean) {
    const rr = Math.max(0, Math.min(rows.length - 1, r))
    const cc = Math.max(0, Math.min(totalWeeks - 1, c))
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
      const ops: CellOp[] = []
      for (let rr = range.r1; rr <= range.r2; rr++)
        for (let cc = range.c1; cc <= range.c2; cc++) {
          const row = rows[rr]
          if (row?.blockId && !lockedWeeks.has(cc + 1) && row.cells.has(cc + 1))
            ops.push({ blockId: row.blockId, week: cc + 1, value: null })
        }
      if (ops.length > 0) write.mutate(ops)
    }
  }

  function onCopy(e: ClipboardEvent<HTMLTableElement>) {
    if (!multi) return
    e.preventDefault()
    e.clipboardData.setData('text/plain', rangeToTsv(rows, range))
  }

  function onPaste(e: ClipboardEvent<HTMLTableElement>) {
    const text = e.clipboardData.getData('text/plain')
    if (!/[\t\n]/.test(text.trim())) return // un solo valore: incolla normale nella cella
    e.preventDefault()
    const result = pasteOps(rows, { r: range.r1, c: range.c1 }, text, totalWeeks, lockedWeeks)
    setNote(m.grid.pasteReport(result.invalid, result.skipped))
    if (result.ops.length > 0) write.mutate(result.ops)
  }

  return (
    <div className="grid gap-2">
      <div className="overflow-x-auto rounded-lg border">
        <table
          ref={tableRef}
          onKeyDown={onKeyDown}
          onCopy={onCopy}
          onPaste={onPaste}
          className="w-full border-collapse text-sm"
        >
          <thead>
            {table.getHeaderGroups().map((hg) => (
              <tr key={hg.id} className="border-b bg-muted/40">
                {hg.headers.map((h, i) => {
                  const week = i
                  return i === 0 ? (
                    <th
                      key={h.id}
                      scope="col"
                      className="sticky left-0 z-[1] min-w-52 bg-muted px-3 py-2 text-left font-medium"
                    >
                      {flexRender(h.column.columnDef.header, h.getContext())}
                    </th>
                  ) : (
                    <th
                      key={h.id}
                      scope="col"
                      className={cn(
                        'min-w-32 px-2 py-1 text-center font-display text-lg font-semibold',
                        deloadWeeks.includes(week) && 'bg-accent text-accent-foreground',
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
                    </th>
                  )
                })}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((tr, r) => {
              const row = tr.original
              const firstOfSlot = r === 0 || rows[r - 1]!.slotId !== row.slotId
              const open = expanded === row.key
              const siblings = rows
                .filter((x) => x.slotId === row.slotId && x.blockId && x.blockId !== row.blockId)
                .map((x) => ({
                  id: x.blockId!,
                  label: `${messages.app.mesocycle.block.roles[x.block!.role]} ${x.block!.position + 1}`,
                }))
              return (
                <Fragment key={row.key}>
                  <tr className={cn('border-b last:border-b-0', firstOfSlot && r > 0 && 'border-t-2')}>
                    <th scope="row" className="sticky left-0 z-[1] bg-card px-3 py-1.5 text-left font-normal">
                      <div className="flex items-center gap-2">
                        <div className="min-w-0 flex-1">
                          {firstOfSlot && <p className="truncate font-medium">{row.exerciseName}</p>}
                          {row.block ? (
                            <p className="truncate text-xs text-muted-foreground">
                              {m.block.roles[row.block.role]}
                              {row.block.technique !== 'none' &&
                                `, ${m.block.techniques[row.block.technique]}`}
                            </p>
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
                    {weekNumbers.map((week) => (
                      <td key={week} className="p-0">
                        {row.blockId ? (
                          <GridCell
                            r={r}
                            c={week - 1}
                            label={m.grid.cell(row.exerciseName, week)}
                            text={formatCell(row.cells.get(week))}
                            locked={lockedWeeks.has(week)}
                            selected={
                              multi &&
                              r >= range.r1 &&
                              r <= range.r2 &&
                              week - 1 >= range.c1 &&
                              week - 1 <= range.c2
                            }
                            onFocus={() => {
                              setActive({ r, c: week - 1 })
                              if (!extending.current) setAnchor({ r, c: week - 1 })
                            }}
                            onShiftClick={() => {
                              setActive({ r, c: week - 1 })
                            }}
                            onCommit={(text) => {
                              const parsed = parseCell(text)
                              if (!parsed.ok) return false
                              write.mutate([{ blockId: row.blockId!, week, value: parsed.value }])
                              return true
                            }}
                          />
                        ) : null}
                      </td>
                    ))}
                  </tr>
                  {open && row.block && (
                    <tr className="border-b bg-muted/30">
                      <td colSpan={totalWeeks + 1} className="p-0">
                        <BlockDetails mesocycleId={mesocycleId} block={row.block} siblings={siblings} />
                      </td>
                    </tr>
                  )}
                </Fragment>
              )
            })}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted-foreground" aria-live="polite">
        {note || m.grid.syntax}
      </p>
    </div>
  )
}

function GridCell({
  r,
  c,
  label,
  text,
  locked,
  selected,
  onFocus,
  onShiftClick,
  onCommit,
}: {
  r: number
  c: number
  label: string
  text: string
  locked: boolean
  selected: boolean
  onFocus: () => void
  onShiftClick: () => void
  onCommit: (text: string) => boolean
}) {
  const [draft, setDraft] = useState(text)
  const [invalid, setInvalid] = useState(false)
  const [prev, setPrev] = useState(text)
  // Il valore salvato cambia (altra cella, incolla, copia): la bozza si riallinea.
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
      title={
        invalid
          ? messages.app.mesocycle.grid.invalid
          : locked
            ? messages.app.mesocycle.grid.locked
            : undefined
      }
      readOnly={locked}
      value={draft}
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
        'h-10 w-full min-w-32 bg-transparent px-2 text-center tabular-nums outline-none focus:bg-accent/60 focus:ring-2 focus:ring-ring focus:ring-inset',
        selected && 'bg-accent/40',
        locked && 'cursor-not-allowed text-muted-foreground',
        invalid && 'bg-destructive/10 ring-2 ring-destructive ring-inset',
      )}
    />
  )
}
