import { ArrowLeftIcon, CaretRightIcon, PlusIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useState } from 'react'
import { NewMesocycleForm } from '@/components/mesocycles/NewMesocycleForm'
import { Button } from '@/components/ui/button'
import { athleteQuery, mesocyclesQuery } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.athleteDetail

export const Route = createFileRoute('/_app/atleti/$athleteId')({
  component: AthletePage,
})

const dateFormat = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short', year: 'numeric' })

function AthletePage() {
  const { athleteId } = Route.useParams()
  const { user } = Route.useRouteContext()
  const [creating, setCreating] = useState(false)
  const athlete = useQuery(athleteQuery(user.id, athleteId))
  const mesocycles = useQuery(mesocyclesQuery(athleteId))

  if (athlete.isSuccess && !athlete.data) {
    return (
      <section className="space-y-4">
        <BackLink />
        <p>{m.notFound}</p>
      </section>
    )
  }

  const name = athlete.data?.athlete?.full_name?.trim() || athlete.data?.athlete?.email || ''
  return (
    <section className="space-y-8">
      <BackLink />
      <h1 className="min-h-14 font-display text-5xl font-bold uppercase">{name}</h1>

      <div className="flex items-center justify-between gap-4">
        <h2 className="font-display text-2xl font-semibold uppercase">{m.mesocycles}</h2>
        {!creating && (
          <Button size="lg" onClick={() => setCreating(true)}>
            <PlusIcon data-icon="inline-start" />
            {m.newMesocycle}
          </Button>
        )}
      </div>

      {creating && <NewMesocycleForm athleteId={athleteId} onCancel={() => setCreating(false)} />}

      {mesocycles.isPending ? (
        <div aria-hidden className="h-20 animate-pulse rounded-xl border bg-muted/50" />
      ) : mesocycles.data?.length === 0 && !creating ? (
        <p className="text-muted-foreground">{m.noMesocycles}</p>
      ) : (
        <ul className="grid gap-3">
          {mesocycles.data?.map((x) => (
            <li key={x.id}>
              <Link
                to="/mesocicli/$mesocycleId"
                params={{ mesocycleId: x.id }}
                className="flex items-center gap-4 rounded-xl border bg-card p-4 transition-colors hover:bg-muted/50 sm:px-6"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">{x.name}</p>
                  <p className="text-sm text-muted-foreground">
                    {dateFormat.format(new Date(x.start_date))} · {m.weeksCount(x.weeks)}
                  </p>
                </div>
                <span
                  className={cn(
                    'rounded-full border px-3 py-1 text-xs font-medium',
                    x.status === 'active' && 'border-primary/40 text-primary',
                  )}
                >
                  {m.status[x.status]}
                </span>
                <CaretRightIcon size={18} className="text-muted-foreground" />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

function BackLink() {
  return (
    <Link
      to="/"
      className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
    >
      <ArrowLeftIcon size={16} />
      {m.back}
    </Link>
  )
}
