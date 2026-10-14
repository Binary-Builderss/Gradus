import { PlusIcon, TrashIcon } from '@phosphor-icons/react'
import { useState } from 'react'
import { ExercisePicker } from '@/components/mesocycles/ExercisePicker'
import { GroupCard } from '@/components/mesocycles/GroupCard'
import { SortableItem, SortableList } from '@/components/mesocycles/Sortable'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { SessionGrid } from '@/components/mesocycles/SessionGrid'
import { Input } from '@/components/ui/input'
import { messages } from '@/lib/messages'
import { nextPosition } from '@/lib/mesocycleSchema'
import { deleteSession, renameSession } from '@/lib/mesocycles'
import { buildGridRows, type BlockData, type WeekData } from '@/lib/gridModel'
import { positionChanges } from '@/lib/slotRules'
import { addExerciseGroup, type GroupRow, reorder, type SlotRow } from '@/lib/slots'
import type { ReactNode } from 'react'

const m = messages.app.mesocycle

export function SessionBlock({
  coachId,
  mesocycleId,
  session,
  groups,
  slots,
  blocks,
  weeks,
  totalWeeks,
  deloadWeeks,
  lockedWeeks,
  handle,
}: {
  coachId: string
  mesocycleId: string
  session: { id: string; position: number; name: string }
  groups: GroupRow[]
  slots: SlotRow[]
  blocks: BlockData[]
  weeks: WeekData[]
  totalWeeks: number
  deloadWeeks: readonly number[]
  lockedWeeks: ReadonlySet<number>
  handle: ReactNode
}) {
  const [adding, setAdding] = useState(false)
  const rename = useEditorMutation(
    (name: string) => renameSession(session.id, mesocycleId, name),
    [['sessions', mesocycleId]],
  )
  const remove = useEditorMutation(() => deleteSession(session.id, mesocycleId), [['sessions', mesocycleId]])
  const groupKeys = [
    ['groups', mesocycleId],
    ['slots', mesocycleId],
  ]
  const addGroup = useEditorMutation(
    (exerciseId: string) =>
      addExerciseGroup({ mesocycleId, sessionId: session.id, position: nextPosition(groups), exerciseId }),
    groupKeys,
  )
  const moveGroups = useEditorMutation(
    (ordered: string[]) => reorder('slot_groups', mesocycleId, positionChanges(ordered, groups)),
    groupKeys,
  )

  const gridRows = buildGridRows(session.id, groups, slots, blocks, weeks)

  return (
    <div className="rounded-lg border bg-card">
      <div className="flex items-center gap-2 border-b px-3 py-2">
        {handle}
        <span className="w-5 text-center font-mono text-xs text-muted-foreground">
          {session.position + 1}
        </span>
        <Input
          key={session.name}
          aria-label={m.sessionName}
          defaultValue={session.name}
          onBlur={(e) => {
            const name = e.target.value.trim()
            if (name && name !== session.name) rename.mutate(name)
            else e.target.value = session.name
          }}
          className="h-8 flex-1 border-transparent bg-transparent px-1.5 text-sm font-medium shadow-none hover:border-input focus-visible:border-ring"
        />
        <Button variant="ghost" size="icon" aria-label={m.removeSession} onClick={() => remove.mutate()}>
          <TrashIcon />
        </Button>
      </div>

      <div className="grid gap-4 p-3">
        {groups.length === 0 && !adding && <p className="text-sm text-muted-foreground">{m.noExercises}</p>}

        <SortableList ids={groups.map((g) => g.id)} onReorder={(ordered) => moveGroups.mutate(ordered)}>
          <ul className="grid gap-3">
            {groups.map((g) => (
              <SortableItem key={g.id} id={g.id}>
                {(groupHandle) => (
                  <GroupCard
                    coachId={coachId}
                    mesocycleId={mesocycleId}
                    group={g}
                    slots={slots.filter((s) => s.group_id === g.id)}
                    handle={groupHandle}
                  />
                )}
              </SortableItem>
            ))}
          </ul>
        </SortableList>

        {gridRows.length > 0 && (
          <div className="grid gap-2">
            <h3 className="text-sm font-semibold">{m.grid.title}</h3>
            <SessionGrid
              mesocycleId={mesocycleId}
              rows={gridRows}
              totalWeeks={totalWeeks}
              deloadWeeks={deloadWeeks}
              lockedWeeks={lockedWeeks}
            />
          </div>
        )}

        {adding ? (
          <ExercisePicker
            coachId={coachId}
            onPick={(id) => {
              addGroup.mutate(id)
              setAdding(false)
            }}
            onClose={() => setAdding(false)}
          />
        ) : (
          <Button variant="outline" className="justify-self-start" onClick={() => setAdding(true)}>
            <PlusIcon data-icon="inline-start" />
            {m.addExercise}
          </Button>
        )}
      </div>
    </div>
  )
}
