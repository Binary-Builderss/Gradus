import { ArrowLeftIcon, CaretRightIcon, PlusIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useState } from 'react'
import { AthleteOverview } from '@/components/mesocycles/AthleteOverview'
import { NewMesocycleForm } from '@/components/mesocycles/NewMesocycleForm'
import { Button } from '@/components/ui/button'
import { athleteQuery, mesocyclesQuery } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'
import { BestSets } from '@/components/athletes/BestSets'
import { MacroSection } from '@/components/nutrition/MacroSection'
import { CloseLink } from '@/components/athletes/CloseLink'
import { usePageTitle } from '@/lib/pageTitle'

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
  const name = athlete.data?.athlete?.full_name?.trim() || athlete.data?.athlete?.email || ''
  usePageTitle(name || undefined)

  if (athlete.isSuccess && !athlete.data) {
    return (
      <section className="space-y-4">
        <BackLink />
        <p>{m.notFound}</p>
      </section>
    )
  }

  const activeMesocycle = mesocycles.data?.find((x) => x.status === 'active')
  return (
    <section className="space-y-5">
      <BackLink />
      <div className="flex items-center justify-between gap-3">
        <h1 className="min-h-7 min-w-0 truncate text-xl font-semibold tracking-tight">{name}</h1>
        {athlete.data && athleteId !== user.id && (
          <CloseLink coachId={user.id} athleteId={athleteId} name={name} />
        )}
      </div>

      {activeMesocycle && (
        <AthleteOverview coachId={user.id} athleteId={athleteId} mesocycle={activeMesocycle} />
      )}

      <MacroSection coachId={user.id} athleteId={athleteId} />

      <BestSets coachId={user.id} athleteId={athleteId} />

      <div className="flex items-center justify-between gap-4">
        <h2 className="text-sm font-semibold">{m.mesocycles}</h2>
        {!creating && (
          <Button onClick={() => setCreating(true)} data-tour="new-mesocycle">
            <PlusIcon data-icon="inline-start" />
            {m.newMesocycle}
          </Button>
        )}
      </div>

      {creating && (
        <NewMesocycleForm coachId={user.id} athleteId={athleteId} onCancel={() => setCreating(false)} />
      )}

      {mesocycles.isPending ? (
        <div aria-hidden className="h-14 animate-pulse rounded-lg border bg-muted/40" />
      ) : mesocycles.data?.length === 0 && !creating ? (
        <div className="space-y-1 rounded-lg border border-dashed p-5">
          <h2 className="text-sm font-semibold">{m.noMesocycles}</h2>
          <p className="max-w-prose text-muted-foreground">{m.noMesocyclesHint}</p>
        </div>
      ) : (
        <ul className="divide-y overflow-hidden rounded-lg border bg-card" data-tour="mesocycle-list">
          {mesocycles.data?.map((x) => (
            <li key={x.id}>
              <Link
                to="/mesocicli/$mesocycleId"
                params={{ mesocycleId: x.id }}
                className="flex items-center gap-4 px-4 py-2.5 transition-colors hover:bg-muted/50"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">{x.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {dateFormat.format(new Date(x.start_date))} · {m.weeksCount(x.weeks)}
                  </p>
                </div>
                <span
                  className={cn(
                    'rounded-md border px-2 py-0.5 text-xs font-medium text-muted-foreground',
                    x.status === 'active' && 'border-primary/40 text-primary',
                  )}
                >
                  {m.status[x.status]}
                </span>
                <CaretRightIcon size={16} className="text-muted-foreground" />
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
