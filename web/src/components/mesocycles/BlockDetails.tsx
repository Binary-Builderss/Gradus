import { TrashIcon } from '@phosphor-icons/react'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { ProgressionForm } from '@/components/mesocycles/ProgressionForm'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { type BlockPatch, deleteBlock, ROLES, TECHNIQUES, updateBlock } from '@/lib/blocks'
import type { BlockData, BlockRole, Technique } from '@/lib/gridModel'
import { messages } from '@/lib/messages'

const m = messages.app.mesocycle.block

const selectClass = 'h-9 rounded-lg border bg-background px-2 text-sm dark:bg-input/30'

export function BlockDetails({
  mesocycleId,
  block,
  siblings,
}: {
  mesocycleId: string
  block: BlockData
  /** Altri blocchi dello stesso esercizio a cui questo può essere collegato. */
  siblings: { id: string; label: string }[]
}) {
  const keys = [
    ['blocks', mesocycleId],
    ['block-weeks', mesocycleId],
  ]
  const patch = useEditorMutation((p: BlockPatch) => updateBlock(mesocycleId, block.id, p), keys)
  const remove = useEditorMutation(() => deleteBlock(mesocycleId, block.id), keys)

  return (
    <div className="grid gap-4 p-4">
      <div className="flex flex-wrap items-end gap-4">
        <Labeled label={m.role}>
          <select
            value={block.role}
            onChange={(e) => patch.mutate({ role: e.target.value as BlockRole })}
            className={selectClass}
          >
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {m.roles[r]}
              </option>
            ))}
          </select>
        </Labeled>
        <Labeled label={m.technique}>
          <select
            value={block.technique}
            onChange={(e) => patch.mutate({ technique: e.target.value as Technique })}
            className={selectClass}
          >
            {TECHNIQUES.map((t) => (
              <option key={t} value={t}>
                {m.techniques[t]}
              </option>
            ))}
          </select>
        </Labeled>
        <Labeled label={m.refBlock}>
          <select
            value={block.ref_block_id ?? ''}
            onChange={(e) => patch.mutate({ ref_block_id: e.target.value || null })}
            className={selectClass}
          >
            <option value="">{m.refNone}</option>
            {siblings.map((s) => (
              <option key={s.id} value={s.id}>
                {s.label}
              </option>
            ))}
          </select>
        </Labeled>
        <Button variant="destructive" className="ml-auto" onClick={() => remove.mutate()}>
          <TrashIcon data-icon="inline-start" />
          {m.remove}
        </Button>
      </div>
      {block.ref_block_id && <p className="text-xs text-muted-foreground">{m.refHint}</p>}

      <fieldset className="flex flex-wrap items-end gap-4">
        <legend className="mb-2 text-sm font-medium">{m.tut}</legend>
        <Seconds
          label={m.eccentric}
          value={block.tut_eccentric_s}
          onCommit={(v) => patch.mutate({ tut_eccentric_s: v })}
        />
        <Seconds
          label={m.bottomPause}
          value={block.tut_bottom_pause_s}
          onCommit={(v) => patch.mutate({ tut_bottom_pause_s: v })}
        />
        <Seconds
          label={m.concentric}
          value={block.tut_concentric_s}
          onCommit={(v) => patch.mutate({ tut_concentric_s: v })}
        />
        <Seconds
          label={m.topPause}
          value={block.tut_top_pause_s}
          onCommit={(v) => patch.mutate({ tut_top_pause_s: v })}
        />
        <Seconds
          label={m.rest}
          value={block.rest_s}
          max={3600}
          onCommit={(v) => patch.mutate({ rest_s: v })}
        />
        <Seconds
          label={m.prep}
          value={block.prep_s}
          max={3600}
          onCommit={(v) => patch.mutate({ prep_s: v })}
        />
      </fieldset>

      <ProgressionForm mesocycleId={mesocycleId} blockId={block.id} />
    </div>
  )
}

function Labeled({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-1.5 text-xs text-muted-foreground">
      {label}
      {children}
    </label>
  )
}

/** Numero intero di secondi, vuoto = non impostato. Salva alla perdita del focus. */
function Seconds({
  label,
  value,
  max = 60,
  onCommit,
}: {
  label: string
  value: number | null
  max?: number
  onCommit: (v: number | null) => void
}) {
  return (
    <Labeled label={label}>
      <Input
        key={value ?? 'empty'}
        type="number"
        min={0}
        max={max}
        defaultValue={value ?? ''}
        onBlur={(e) => {
          const raw = e.target.value.trim()
          const next = raw === '' ? null : Number(raw)
          if (next !== null && !(Number.isInteger(next) && next >= 0 && next <= max)) {
            e.target.value = value === null ? '' : String(value)
          } else if (next !== value) onCommit(next)
        }}
        className="h-9 w-24 text-sm"
      />
    </Labeled>
  )
}
