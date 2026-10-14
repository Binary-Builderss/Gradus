import { ArrowLeftIcon, PlusIcon, TrashIcon } from '@phosphor-icons/react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { SaveStatus } from '@/components/mesocycles/SaveStatus'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { nextPosition, toggleDeload } from '@/lib/mesocycleSchema'
import {
  addSession,
  deleteSession,
  mesocycleQuery,
  renameSession,
  sessionsQuery,
  updateMesocycle,
  updateWeeks,
} from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle
const athleteMessages = messages.app.athleteDetail

export const Route = createFileRoute('/_app/mesocicli/$mesocycleId')({
  component: MesocyclePage,
})

function MesocyclePage() {
  const { mesocycleId } = Route.useParams()
  const queryClient = useQueryClient()
  const meso = useQuery(mesocycleQuery(mesocycleId))
  const sessions = useQuery(sessionsQuery(mesocycleId))

  const save = <V,>(fn: (v: V) => Promise<unknown>, keys: string[][]) =>
    // Le mutazioni dell'editor condividono la chiave: la barra di stato le segue tutte.
    ({
      mutationKey: ['editor'],
      mutationFn: fn,
      onSettled: () => Promise.all(keys.map((queryKey) => queryClient.invalidateQueries({ queryKey }))),
    })

  const mesoKeys = [['mesocycle', mesocycleId], ['mesocycles']]
  const rename = useMutation(save((v: { name: string }) => updateMesocycle(mesocycleId, v), mesoKeys))
  const setDeload = useMutation(
    save((v: number[]) => updateMesocycle(mesocycleId, { deload_weeks: v }), mesoKeys),
  )
  const setWeeks = useMutation(
    save((v: { weeks: number; deload: number[] }) => updateWeeks(mesocycleId, v.weeks, v.deload), mesoKeys),
  )
  const sessionKeys = [['sessions', mesocycleId]]
  const add = useMutation(
    save((v: { position: number; name: string }) => addSession(mesocycleId, v.position, v.name), sessionKeys),
  )
  const renameS = useMutation(
    save((v: { id: string; name: string }) => renameSession(v.id, mesocycleId, v.name), sessionKeys),
  )
  const remove = useMutation(save((id: string) => deleteSession(id, mesocycleId), sessionKeys))

  if (meso.isSuccess && !meso.data) return <p>{m.notFound}</p>
  const data = meso.data
  const list = sessions.data ?? []

  return (
    <section className="space-y-8">
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
          <div className="grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end">
            <Input
              key={data.name}
              aria-label={athleteMessages.name}
              defaultValue={data.name}
              onBlur={(e) => {
                const name = e.target.value.trim()
                if (name && name !== data.name) rename.mutate({ name })
                else e.target.value = data.name
              }}
              className="h-auto border-transparent bg-transparent px-0 font-display text-4xl font-bold uppercase shadow-none focus-visible:border-input sm:text-5xl"
            />
            <label className="flex items-center gap-3 text-sm text-muted-foreground">
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
                className="h-10 w-20 text-base"
              />
            </label>
          </div>

          <div className="space-y-3">
            <h2 className="font-display text-2xl font-semibold uppercase">{m.deload}</h2>
            <ul className="flex flex-wrap gap-2">
              {Array.from({ length: data.weeks }, (_, i) => i + 1).map((week) => {
                const on = data.deload_weeks.includes(week)
                return (
                  <li key={week}>
                    <button
                      type="button"
                      aria-pressed={on}
                      onClick={() => setDeload.mutate(toggleDeload(data.deload_weeks, week, data.weeks))}
                      className={cn(
                        'h-10 min-w-12 rounded-lg border px-3 font-display text-lg font-semibold transition-colors',
                        on
                          ? 'border-primary bg-primary text-primary-foreground'
                          : 'text-muted-foreground hover:bg-muted',
                      )}
                    >
                      {m.weekShort(week)}
                    </button>
                  </li>
                )
              })}
            </ul>
            <p className="text-sm text-muted-foreground">{m.deloadHint}</p>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between gap-4">
              <h2 className="font-display text-2xl font-semibold uppercase">{m.sessions}</h2>
              <Button
                size="lg"
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
              <ul className="grid gap-3">
                {list.map((s) => (
                  <li key={s.id} className="flex items-center gap-3 rounded-xl border bg-card p-3 sm:px-4">
                    <span className="w-8 text-center font-display text-2xl font-semibold text-muted-foreground">
                      {s.position + 1}
                    </span>
                    <Input
                      key={s.name}
                      aria-label={m.sessionName}
                      defaultValue={s.name}
                      onBlur={(e) => {
                        const name = e.target.value.trim()
                        if (name && name !== s.name) renameS.mutate({ id: s.id, name })
                        else e.target.value = s.name
                      }}
                      className="h-10 flex-1 text-base"
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      aria-label={m.removeSession}
                      onClick={() => remove.mutate(s.id)}
                    >
                      <TrashIcon />
                    </Button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </>
      ) : (
        <div aria-hidden className="h-40 animate-pulse rounded-xl border bg-muted/50" />
      )}
    </section>
  )
}
