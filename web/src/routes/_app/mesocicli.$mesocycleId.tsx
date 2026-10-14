import { ArrowLeftIcon, PlusIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { useMemo } from 'react'
import { createFileRoute, Link } from '@tanstack/react-router'
import { SaveStatus } from '@/components/mesocycles/SaveStatus'
import { SessionBlock } from '@/components/mesocycles/SessionBlock'
import { SortableItem, SortableList } from '@/components/mesocycles/Sortable'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { nextPosition, toggleDeload } from '@/lib/mesocycleSchema'
import { addSession, mesocycleQuery, sessionsQuery, updateMesocycle, updateWeeks } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { positionChanges } from '@/lib/slotRules'
import { groupsQuery, reorder, slotsQuery } from '@/lib/slots'
import { blocksQuery, lockedWeeksQuery, weeksQuery } from '@/lib/blocks'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle
const athleteMessages = messages.app.athleteDetail

export const Route = createFileRoute('/_app/mesocicli/$mesocycleId')({
  component: MesocyclePage,
})

function MesocyclePage() {
  const { mesocycleId } = Route.useParams()
  const { user } = Route.useRouteContext()
  const meso = useQuery(mesocycleQuery(mesocycleId))
  const sessions = useQuery(sessionsQuery(mesocycleId))
  const groups = useQuery(groupsQuery(mesocycleId))
  const slots = useQuery(slotsQuery(mesocycleId))
  const blocks = useQuery(blocksQuery(mesocycleId))
  const weekRows = useQuery(weeksQuery(mesocycleId))
  const locked = useQuery(lockedWeeksQuery(mesocycleId))
  const lockedWeeks = useMemo(() => new Set(locked.data ?? []), [locked.data])

  const mesoKeys = [['mesocycle', mesocycleId], ['mesocycles']]
  const sessionKeys = [['sessions', mesocycleId]]
  const rename = useEditorMutation((v: { name: string }) => updateMesocycle(mesocycleId, v), mesoKeys)
  const setDeload = useEditorMutation(
    (v: number[]) => updateMesocycle(mesocycleId, { deload_weeks: v }),
    mesoKeys,
  )
  const setWeeks = useEditorMutation(
    (v: { weeks: number; deload: number[] }) => updateWeeks(mesocycleId, v.weeks, v.deload),
    mesoKeys,
  )
  const add = useEditorMutation(
    (v: { position: number; name: string }) => addSession(mesocycleId, v.position, v.name),
    sessionKeys,
  )
  const moveSessions = useEditorMutation(
    (ordered: string[]) => reorder('sessions', mesocycleId, positionChanges(ordered, sessions.data ?? [])),
    sessionKeys,
  )

  if (meso.isSuccess && !meso.data) return <p>{m.notFound}</p>
  const data = meso.data
  const list = sessions.data ?? []

  return (
    <section className="space-y-5">
      <div className="flex items-center justify-between gap-4">
        {data ? (
          <Link
            to="/atleti/$athleteId"
            params={{ athleteId: data.athlete_id }}
            className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
          >
            <ArrowLeftIcon size={16} />
            {athleteMessages.mesocycles}
          </Link>
        ) : (
          <span />
        )}
        <SaveStatus />
      </div>

      {data ? (
        <>
          <div className="grid gap-3">
            <div className="flex flex-wrap items-center gap-3">
              <Input
                key={data.name}
                aria-label={athleteMessages.name}
                defaultValue={data.name}
                onBlur={(e) => {
                  const name = e.target.value.trim()
                  if (name && name !== data.name) rename.mutate({ name })
                  else e.target.value = data.name
                }}
                className="h-auto w-auto min-w-0 flex-1 border-transparent bg-transparent px-1 py-0.5 text-xl font-semibold tracking-tight shadow-none hover:border-input focus-visible:border-ring md:text-xl"
              />
              <span className="rounded-full bg-accent px-2 py-0.5 text-xs font-medium text-accent-foreground">
                {athleteMessages.status[data.status]}
              </span>
            </div>
            <label className="flex items-center gap-2 text-xs text-muted-foreground">
              {athleteMessages.weeks}
              <Input
                key={data.weeks}
                type="number"
                min={1}
                max={52}
                defaultValue={data.weeks}
                onBlur={(e) => {
                  const weeks = Number(e.target.value)
                  if (Number.isInteger(weeks) && weeks >= 1 && weeks <= 52 && weeks !== data.weeks)
                    setWeeks.mutate({ weeks, deload: data.deload_weeks })
                  else e.target.value = String(data.weeks)
                }}
                className="h-8 w-16 text-sm"
              />
            </label>
          </div>

          <div className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-lg border bg-card px-3 py-2">
            <h2 className="text-xs font-medium text-muted-foreground">{m.deload}</h2>
            <ul className="flex flex-wrap gap-1">
              {Array.from({ length: data.weeks }, (_, i) => i + 1).map((week) => {
                const on = data.deload_weeks.includes(week)
                return (
                  <li key={week}>
                    <button
                      type="button"
                      aria-pressed={on}
                      onClick={() => setDeload.mutate(toggleDeload(data.deload_weeks, week, data.weeks))}
                      className={cn(
                        'h-7 min-w-9 rounded-md border px-2 font-mono text-xs transition-colors',
                        on
                          ? 'border-warning-foreground/40 bg-warning text-warning-foreground'
                          : 'text-muted-foreground hover:bg-muted',
                      )}
                    >
                      {m.weekShort(week)}
                    </button>
                  </li>
                )
              })}
            </ul>
            <p className="text-xs text-muted-foreground">{m.deloadHint}</p>
          </div>

          <div className="space-y-3">
            <div className="flex items-center justify-between gap-4">
              <h2 className="text-sm font-semibold">{m.sessions}</h2>
              <Button
                onClick={() =>
                  add.mutate({ position: nextPosition(list), name: m.defaultSessionName(list.length + 1) })
                }
              >
                <PlusIcon data-icon="inline-start" />
                {m.addSession}
              </Button>
            </div>
            {sessions.isSuccess && list.length === 0 ? (
              <p className="text-muted-foreground">{m.noSessions}</p>
            ) : (
              <SortableList ids={list.map((x) => x.id)} onReorder={(ordered) => moveSessions.mutate(ordered)}>
                <ul className="grid gap-3">
                  {list.map((x) => (
                    <SortableItem key={x.id} id={x.id}>
                      {(handle) => (
                        <SessionBlock
                          coachId={user.id}
                          mesocycleId={mesocycleId}
                          session={x}
                          groups={(groups.data ?? []).filter((g) => g.session_id === x.id)}
                          slots={slots.data ?? []}
                          blocks={blocks.data ?? []}
                          weeks={weekRows.data ?? []}
                          totalWeeks={data.weeks}
                          deloadWeeks={data.deload_weeks}
                          lockedWeeks={lockedWeeks}
                          handle={handle}
                        />
                      )}
                    </SortableItem>
                  ))}
                </ul>
              </SortableList>
            )}
          </div>
        </>
      ) : (
        <div aria-hidden className="h-40 animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
