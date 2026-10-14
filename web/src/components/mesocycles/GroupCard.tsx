import { PlusIcon, XIcon } from '@phosphor-icons/react'
import { useState, type ReactNode } from 'react'
import { ExercisePicker } from '@/components/mesocycles/ExercisePicker'
import { SortableItem, SortableList } from '@/components/mesocycles/Sortable'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { messages } from '@/lib/messages'
import { nextPosition } from '@/lib/mesocycleSchema'
import { type GroupKind, GROUP_KINDS, positionChanges } from '@/lib/slotRules'
import {
  addSlotToGroup,
  type GroupRow,
  removeSlot,
  reorder,
  setGroupKind,
  setGroupRest,
  type SlotRow,
} from '@/lib/slots'

const m = messages.app.mesocycle

export function GroupCard({
  coachId,
  mesocycleId,
  group,
  slots,
  handle,
}: {
  coachId: string
  mesocycleId: string
  group: GroupRow
  slots: SlotRow[]
  handle: ReactNode
}) {
  const [adding, setAdding] = useState(false)
  const keys = [
    ['groups', mesocycleId],
    ['slots', mesocycleId],
  ]
  const changeKind = useEditorMutation((kind: GroupKind) => setGroupKind(mesocycleId, group.id, kind), keys)
  const changeRest = useEditorMutation(
    (patch: { rest_between_s?: number; rest_after_round_s?: number }) =>
      setGroupRest(mesocycleId, group.id, patch),
    keys,
  )
  const addSlot = useEditorMutation(
    (exerciseId: string) =>
      addSlotToGroup({ mesocycleId, group, position: nextPosition(slots), count: slots.length, exerciseId }),
    keys,
  )
  const dropSlot = useEditorMutation(
    (slotId: string) => removeSlot({ mesocycleId, group, slotId, count: slots.length }),
    keys,
  )
  const moveSlots = useEditorMutation(
    (ordered: string[]) => reorder('slots', mesocycleId, positionChanges(ordered, slots)),
    keys,
  )

  const chained = group.kind !== 'single'
  return (
    <div className="grid gap-2 rounded-md border bg-background p-2">
      <div className="flex items-center gap-2">
        {handle}
        <select
          aria-label={m.groupKind}
          value={group.kind}
          disabled={slots.length < 2}
          onChange={(e) => changeKind.mutate(e.target.value as GroupKind)}
          className="h-8 rounded-md border bg-background px-2 text-sm disabled:opacity-60 dark:bg-input/30"
        >
          {GROUP_KINDS.map((k) => (
            <option key={k} value={k} disabled={k === 'single'}>
              {m.kinds[k]}
            </option>
          ))}
        </select>
        {chained && (
          <>
            <RestField
              label={m.restBetween}
              value={group.rest_between_s}
              onCommit={(rest_between_s) => changeRest.mutate({ rest_between_s })}
            />
            <RestField
              label={m.restAfterRound}
              value={group.rest_after_round_s}
              onCommit={(rest_after_round_s) => changeRest.mutate({ rest_after_round_s })}
            />
          </>
        )}
      </div>

      <SortableList ids={slots.map((s) => s.id)} onReorder={(ordered) => moveSlots.mutate(ordered)}>
        <ul className="grid gap-1.5">
          {slots.map((s) => (
            <SortableItem key={s.id} id={s.id}>
              {(slotHandle) => (
                <div className="flex items-center gap-2 rounded bg-muted/60 py-0.5 pr-1 pl-1">
                  {slotHandle}
                  <span className="flex-1 truncate text-sm font-medium">{s.exercise_name}</span>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-label={m.removeExercise}
                    onClick={() => dropSlot.mutate(s.id)}
                  >
                    <XIcon />
                  </Button>
                </div>
              )}
            </SortableItem>
          ))}
        </ul>
      </SortableList>

      {adding ? (
        <ExercisePicker
          coachId={coachId}
          onPick={(id) => {
            addSlot.mutate(id)
            setAdding(false)
          }}
          onClose={() => setAdding(false)}
        />
      ) : (
        <Button variant="ghost" size="sm" className="justify-self-start" onClick={() => setAdding(true)}>
          <PlusIcon data-icon="inline-start" />
          {m.addToGroup}
        </Button>
      )}
    </div>
  )
}

function RestField({
  label,
  value,
  onCommit,
}: {
  label: string
  value: number
  onCommit: (seconds: number) => void
}) {
  return (
    <label className="flex items-center gap-2 text-xs text-muted-foreground">
      {label}
      <Input
        key={value}
        type="number"
        min={0}
        max={3600}
        defaultValue={value}
        onBlur={(e) => {
          const seconds = Number(e.target.value)
          if (Number.isInteger(seconds) && seconds >= 0 && seconds <= 3600 && seconds !== value)
            onCommit(seconds)
          else e.target.value = String(value)
        }}
        className="h-8 w-16 text-sm"
      />
      {m.seconds}
    </label>
  )
}
