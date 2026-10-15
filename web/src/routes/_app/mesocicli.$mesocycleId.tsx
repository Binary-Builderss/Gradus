import { ArrowLeftIcon, CalendarBlankIcon, PlusIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { useMemo, useState } from 'react'
import { Tabs } from 'radix-ui'
import { createFileRoute, Link } from '@tanstack/react-router'
import { MesocycleSummary } from '@/components/mesocycles/MesocycleSummary'
import { SaveStatus } from '@/components/mesocycles/SaveStatus'
import { SessionBlock } from '@/components/mesocycles/SessionBlock'
import { MesocycleSettings } from '@/components/mesocycles/MesocycleSettings'
import { useEditorMutation } from '@/components/mesocycles/useEditorMutation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { nextPosition, toggleDeload } from '@/lib/mesocycleSchema'
import { addSession, mesocycleQuery, sessionsQuery, updateMesocycle, updateWeeks } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { positionChanges } from '@/lib/slotRules'
import { groupsQuery, reorder, slotsQuery } from '@/lib/slots'
import { blocksQuery, lockedWeeksQuery, weeksQuery } from '@/lib/blocks'

const m = messages.app.mesocycle
const athleteMessages = messages.app.athleteDetail

const viewTrigger =
  'rounded px-3 py-1 text-sm font-medium text-muted-foreground transition-colors outline-none hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 data-[state=active]:bg-background data-[state=active]:text-foreground data-[state=active]:shadow-sm'

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
  const [selected, setSelected] = useState<string | null>(null)
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
  const current = list.find((x) => x.id === selected) ?? list[0]

  function moveSession(id: string, direction: -1 | 1) {
    const ids = list.map((x) => x.id)
    const from = ids.indexOf(id)
    const to = from + direction
    if (from < 0 || to < 0 || to >= ids.length) return
    ;[ids[from], ids[to]] = [ids[to]!, ids[from]!]
    moveSessions.mutate(ids)
  }
  function addNewSession() {
    add.mutate(
      { position: nextPosition(list), name: m.defaultSessionName(list.length + 1) },
      { onSuccess: (id) => setSelected(id) },
    )
  }

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
        <div data-tour="save-status">
          <SaveStatus />
        </div>
      </div>

      {data ? (
        <>
          <div className="grid gap-2">
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
            <MesocycleSettings
              weeks={data.weeks}
              deloadWeeks={data.deload_weeks}
              onWeeks={(weeks) => setWeeks.mutate({ weeks, deload: data.deload_weeks })}
              onToggleDeload={(week) => setDeload.mutate(toggleDeload(data.deload_weeks, week, data.weeks))}
            />
          </div>

          <Tabs.Root defaultValue="plan" className="grid gap-4">
            <Tabs.List
              aria-label={m.tabs.plan + ' / ' + m.tabs.summary}
              className="inline-flex w-fit gap-0.5 rounded-md bg-muted p-0.5"
              data-tour="meso-tabs"
            >
              <Tabs.Trigger value="plan" className={viewTrigger}>
                {m.tabs.plan}
              </Tabs.Trigger>
              <Tabs.Trigger value="summary" className={viewTrigger}>
                {m.tabs.summary}
              </Tabs.Trigger>
            </Tabs.List>
            <Tabs.Content value="plan" className="outline-none">
              {sessions.isSuccess && list.length === 0 ? (
                <div className="grid justify-items-start gap-3 rounded-lg border border-dashed p-5">
                  <CalendarBlankIcon size={20} className="text-muted-foreground" />
                  <div className="space-y-1">
                    <h2 className="text-sm font-semibold">{m.noSessions}</h2>
                    <p className="max-w-prose text-muted-foreground">{m.noSessionsHint}</p>
                  </div>
                  <Button onClick={addNewSession}>
                    <PlusIcon data-icon="inline-start" />
                    {m.addSession}
                  </Button>
                </div>
              ) : (
                <Tabs.Root value={current?.id ?? ''} onValueChange={setSelected}>
                  <div className="flex items-center gap-2 border-b" data-tour="session-tabs">
                    <Tabs.List aria-label={m.sessions} className="flex min-w-0 gap-1 overflow-x-auto">
                      {list.map((x) => (
                        <Tabs.Trigger
                          key={x.id}
                          value={x.id}
                          className="-mb-px max-w-48 truncate border-b-2 border-transparent px-3 py-2 text-sm font-medium text-muted-foreground transition-colors outline-none hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 data-[state=active]:border-primary data-[state=active]:text-foreground"
                        >
                          {x.name}
                        </Tabs.Trigger>
                      ))}
                    </Tabs.List>
                    <Button variant="ghost" size="sm" className="mb-1 shrink-0" onClick={addNewSession}>
                      <PlusIcon data-icon="inline-start" />
                      {m.addSessionShort}
                    </Button>
                  </div>
                  {current && (
                    <Tabs.Content value={current.id} className="pt-4 outline-none">
                      <SessionBlock
                        key={current.id}
                        coachId={user.id}
                        mesocycleId={mesocycleId}
                        session={current}
                        groups={(groups.data ?? []).filter((g) => g.session_id === current.id)}
                        slots={slots.data ?? []}
                        blocks={blocks.data ?? []}
                        weeks={weekRows.data ?? []}
                        totalWeeks={data.weeks}
                        deloadWeeks={data.deload_weeks}
                        lockedWeeks={lockedWeeks}
                        index={list.indexOf(current)}
                        total={list.length}
                        onMove={(direction) => moveSession(current.id, direction)}
                      />
                    </Tabs.Content>
                  )}
                </Tabs.Root>
              )}
            </Tabs.Content>
            <Tabs.Content value="summary" className="outline-none">
              <MesocycleSummary
                mesocycleId={mesocycleId}
                totalWeeks={data.weeks}
                deloadWeeks={data.deload_weeks}
                sessions={list}
                groups={groups.data ?? []}
                slots={slots.data ?? []}
                blocks={blocks.data ?? []}
                weeks={weekRows.data ?? []}
              />
            </Tabs.Content>
          </Tabs.Root>
        </>
      ) : (
        <div aria-hidden className="h-40 animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
