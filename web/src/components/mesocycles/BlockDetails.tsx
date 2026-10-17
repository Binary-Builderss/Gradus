import { TrashIcon } from '@phosphor-icons/react'
import type { ReactNode } from 'react'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { ProgressionForm } from '@/components/mesocycles/ProgressionForm'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { type BlockPatch, deleteBlock, ROLES, TECHNIQUES, updateBlock } from '@/lib/blocks'
import type { BlockData, BlockRole, Technique } from '@/lib/gridModel'
import { messages } from '@/lib/messages'
import { describeTempo, formatSeconds, NO_TEMPO, type Tempo } from '@/lib/tempo'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle.block
const progression = messages.app.mesocycle.progression

const selectClass = 'h-9 rounded-md border bg-background px-2 text-sm dark:bg-input/30'

const TEMPO_PRESETS = {
  natural: [1, 0, 1, 0],
  controlled: [3, 0, 1, 0],
  bottomHold: [2, 2, 1, 0],
} as const
const REST_PRESETS = [30, 60, 90, 120, 180, 300] as const

export function BlockDetails({
  coachId,
  mesocycleId,
  block,
  siblings,
}: {
  coachId: string
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
  const tempo: Tempo = block
  const setTempo = (t: Tempo) => patch.mutate(t)

  return (
    <div className="grid gap-6 p-4">
      <p role="status" className="text-xs text-muted-foreground">
        {patch.isPending ? m.saving : patch.isSuccess ? m.saved : m.autosave}
      </p>
      <Section title={m.work.title} hint={m.work.hint}>
        <div role="radiogroup" aria-label={m.role} className="flex flex-wrap gap-2">
          {ROLES.map((r) => (
            <Choice
              key={r}
              selected={block.role === r}
              role="radio"
              onClick={() => patch.mutate({ role: r as BlockRole })}
            >
              {m.roles[r]}
            </Choice>
          ))}
        </div>
        <p className="text-sm text-muted-foreground">{m.roleHints[block.role]}</p>
        {(block.role === 'backoff' || block.ref_block_id) && (
          <div className="grid max-w-md gap-1.5">
            <label className="grid gap-1.5 text-xs text-muted-foreground">
              {m.refBlock}
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
            </label>
            <p className="text-xs text-muted-foreground">{m.refHint}</p>
          </div>
        )}
        <div className="grid max-w-md gap-1.5">
          <label className="grid gap-1.5 text-xs text-muted-foreground">
            {m.technique}
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
          </label>
          <p className="text-xs text-muted-foreground">{m.techniqueHints[block.technique]}</p>
        </div>
      </Section>

      <Section title={m.tempo.title} hint={m.tempo.hint}>
        <div className="flex flex-wrap items-end gap-3">
          <Seconds
            label={m.tempo.eccentric}
            value={block.tut_eccentric_s}
            onCommit={(v) => patch.mutate({ tut_eccentric_s: v })}
          />
          <Seconds
            label={m.tempo.bottomPause}
            value={block.tut_bottom_pause_s}
            onCommit={(v) => patch.mutate({ tut_bottom_pause_s: v })}
          />
          <Seconds
            label={m.tempo.concentric}
            value={block.tut_concentric_s}
            onCommit={(v) => patch.mutate({ tut_concentric_s: v })}
          />
          <Seconds
            label={m.tempo.topPause}
            value={block.tut_top_pause_s}
            onCommit={(v) => patch.mutate({ tut_top_pause_s: v })}
          />
          <span className="pb-2 text-xs text-muted-foreground">{m.tempo.unit}</span>
        </div>
        <p className="text-sm">{describeTempo(tempo)}</p>
        <div className="flex flex-wrap items-center gap-2" role="group" aria-label={m.tempo.presets}>
          <span className="text-xs text-muted-foreground">{m.tempo.presets}</span>
          {(Object.keys(TEMPO_PRESETS) as (keyof typeof TEMPO_PRESETS)[]).map((key) => {
            const [a, b, c, d] = TEMPO_PRESETS[key]
            return (
              <Button
                key={key}
                type="button"
                variant="outline"
                size="sm"
                onClick={() =>
                  setTempo({
                    tut_eccentric_s: a,
                    tut_bottom_pause_s: b,
                    tut_concentric_s: c,
                    tut_top_pause_s: d,
                  })
                }
              >
                {m.tempo.presetNames[key]} {a}-{b}-{c}-{d}
              </Button>
            )
          })}
          <Button type="button" variant="ghost" size="sm" onClick={() => setTempo(NO_TEMPO)}>
            {m.tempo.clear}
          </Button>
        </div>
      </Section>

      <Section title={m.rests.title} hint={m.rests.hint}>
        <div className="grid gap-2">
          <span className="text-xs text-muted-foreground">{m.rests.between}</span>
          <div className="flex flex-wrap items-center gap-2">
            {REST_PRESETS.map((s) => (
              <Choice
                key={s}
                selected={block.rest_s === s}
                role="radio"
                onClick={() => patch.mutate({ rest_s: block.rest_s === s ? null : s })}
              >
                {formatSeconds(s)}
              </Choice>
            ))}
            <Seconds
              label={m.rests.custom}
              value={block.rest_s}
              max={3600}
              onCommit={(v) => patch.mutate({ rest_s: v })}
            />
          </div>
          <p className="text-sm">
            {block.rest_s === null ? m.rests.none : m.rests.sentence(formatSeconds(block.rest_s))}
          </p>
        </div>
        <div className="grid gap-1">
          <Seconds
            label={m.rests.prep}
            value={block.prep_s}
            max={3600}
            onCommit={(v) => patch.mutate({ prep_s: v })}
          />
          <p className="text-xs text-muted-foreground">{m.rests.prepHint}</p>
        </div>
      </Section>

      <Section title={progression.title}>
        <ProgressionForm coachId={coachId} mesocycleId={mesocycleId} blockId={block.id} />
      </Section>

      <div className="border-t pt-3">
        <Button variant="destructive" onClick={() => remove.mutate()}>
          <TrashIcon data-icon="inline-start" />
          {m.remove}
        </Button>
      </div>
    </div>
  )
}

function Section({ title, hint, children }: { title: string; hint?: string; children: ReactNode }) {
  return (
    <section className="grid gap-3 border-t pt-4 first:border-t-0 first:pt-0">
      <div className="grid gap-0.5">
        <h3 className="text-sm font-semibold">{title}</h3>
        {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
      </div>
      {children}
    </section>
  )
}

function Choice({
  selected,
  children,
  ...props
}: { selected: boolean; children: ReactNode } & Omit<React.ComponentProps<'button'>, 'children'>) {
  return (
    <button
      type="button"
      aria-checked={selected}
      {...props}
      className={cn(
        'h-9 rounded-md border px-3 text-sm transition-colors focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none active:scale-[0.98]',
        selected
          ? 'border-primary bg-primary/10 font-medium text-primary'
          : 'bg-background hover:bg-muted dark:bg-input/30',
      )}
    >
      {children}
    </button>
  )
}

function Labeled({ label, children }: { label: string; children: ReactNode }) {
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
