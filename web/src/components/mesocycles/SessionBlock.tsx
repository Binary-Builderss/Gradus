import { BarbellIcon, CaretLeftIcon, CaretRightIcon, PlusIcon, TrashIcon } from '@phosphor-icons/react'
import { useState } from 'react'
import { ExercisePicker } from '@/components/mesocycles/ExercisePicker'
import { GroupCard } from '@/components/mesocycles/GroupCard'
import { SortableItem, SortableList } from '@/components/mesocycles/Sortable'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { Collapsible } from '@/components/ui/collapsible'
import { SessionGrid } from '@/components/mesocycles/SessionGrid'
import { Input } from '@/components/ui/input'
import { messages } from '@/lib/messages'
import { nextPosition } from '@/lib/mesocycleSchema'
import { deleteSession, renameSession } from '@/lib/mesocycles'
import { buildGridRows, type BlockData, type WeekData } from '@/lib/gridModel'
import { positionChanges } from '@/lib/slotRules'
import { addExerciseGroup, type GroupRow, reorder, type SlotRow } from '@/lib/slots'

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
  index,
  total,
  onMove,
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
  index: number
  total: number
  onMove: (direction: -1 | 1) => void
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

  const picker = adding ? (
    <ExercisePicker
      coachId={coachId}
      onPick={(id) => {
        addGroup.mutate(id)
        setAdding(false)
      }}
      onClose={() => setAdding(false)}
    />
  ) : null

  return (
    <div className="rounded-lg border bg-card">
      <div className="flex items-center gap-1 border-b px-3 py-2">
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
        <Button
          variant="ghost"
          size="icon"
          aria-label={m.moveSessionLeft}
          title={m.moveSessionLeft}
          disabled={index === 0}
          onClick={() => onMove(-1)}
        >
          <CaretLeftIcon />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          aria-label={m.moveSessionRight}
          title={m.moveSessionRight}
          disabled={index === total - 1}
          onClick={() => onMove(1)}
        >
          <CaretRightIcon />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          aria-label={m.removeSession}
          title={m.removeSession}
          onClick={() => remove.mutate()}
        >
          <TrashIcon />
        </Button>
      </div>

      <div className="grid gap-4 p-3">
        {groups.length === 0 ? (
          <div className="grid justify-items-start gap-3 rounded-lg border border-dashed p-5">
            <BarbellIcon size={20} className="text-muted-foreground" />
            <div className="space-y-1">
              <h3 className="text-sm font-semibold">{m.noExercises}</h3>
              <p className="max-w-prose text-muted-foreground">{m.noExercisesHint}</p>
            </div>
            {picker ?? (
              <Button onClick={() => setAdding(true)} data-tour="add-exercise">
                <PlusIcon data-icon="inline-start" />
                {m.addFirstExercise}
              </Button>
            )}
          </div>
        ) : (
          <>
            {gridRows.length > 0 && (
              <SessionGrid
                mesocycleId={mesocycleId}
                rows={gridRows}
                totalWeeks={totalWeeks}
                deloadWeeks={deloadWeeks}
                lockedWeeks={lockedWeeks}
              />
            )}

            {picker ?? (
              <Button
                className="h-9 w-full bg-foreground text-background hover:bg-foreground/85"
                onClick={() => setAdding(true)}
                data-tour="add-exercise"
              >
                <PlusIcon data-icon="inline-start" />
                {m.addExercise}
              </Button>
            )}

            <Collapsible title={m.structure} className="border-t pt-3">
              <p className="max-w-prose text-xs text-muted-foreground">{m.structureHint}</p>
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
            </Collapsible>
          </>
        )}
      </div>
    </div>
  )
}
