import { UsersThreeIcon, WarningCircleIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { InviteAthlete } from '@/components/athletes/InviteAthlete'
import { TourBanner } from '@/components/tour/TourBanner'
import { useGuidedTour } from '@/components/tour/useGuidedTour'
import { Button } from '@/components/ui/button'
import { type AthleteRow, athletesQuery } from '@/lib/athletes'
import { initials, lastWorkoutLabel } from '@/lib/athleteStats'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.athletes

export const Route = createFileRoute('/_app/')({
  component: AthletesPage,
})

function AthletesPage() {
  const { user } = Route.useRouteContext()
  const { data, isPending, isError, refetch } = useQuery(athletesQuery(user.id))
  const startTour = useGuidedTour(user.id)

  return (
    <section className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <h1 className="text-xl font-semibold tracking-tight">{m.title}</h1>
        <InviteAthlete />
      </div>
      <TourBanner onStart={() => void startTour()} />
      {isPending ? (
        <ListSkeleton />
      ) : isError ? (
        <ErrorState onRetry={() => void refetch()} />
      ) : data.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="overflow-hidden rounded-lg border bg-card" data-tour="athlete-list">
          <div className="hidden grid-cols-[1fr_9rem_9rem] gap-4 border-b bg-muted/50 px-4 py-2 text-xs font-medium text-muted-foreground sm:grid">
            <span>{m.title}</span>
            <span>{m.lastWorkout}</span>
            <span>{m.last7Days}</span>
          </div>
          <ul className="divide-y">
            {data.map((a) => (
              <AthleteItem key={a.id} athlete={a} />
            ))}
          </ul>
        </div>
      )}
    </section>
  )
}

function AthleteItem({ athlete: a }: { athlete: AthleteRow }) {
  const pending = a.status === 'pending'
  return (
    <li className="relative grid grid-cols-[auto_1fr] items-center gap-x-3 gap-y-1 px-4 py-3 transition-colors focus-within:bg-muted/50 hover:bg-muted/50 sm:grid-cols-[1fr_9rem_9rem] sm:gap-x-4 sm:py-2.5">
      <div className="col-span-2 flex min-w-0 items-center gap-3 sm:col-span-1">
        <span
          aria-hidden
          className="grid size-8 shrink-0 place-items-center rounded-full bg-accent text-xs font-semibold text-accent-foreground"
        >
          {initials(a.name)}
        </span>
        <div className="min-w-0">
          <p className="truncate font-medium">
            <Link
              to="/atleti/$athleteId"
              params={{ athleteId: a.id }}
              className="after:absolute after:inset-0 focus-visible:outline-none"
            >
              {a.name}
            </Link>
            {a.isSelf && <span className="ml-2 text-xs font-normal text-muted-foreground">{m.self}</span>}
          </p>
          <p className="truncate text-xs text-muted-foreground">{pending ? m.pending : a.email}</p>
        </div>
      </div>
      <Cell label={m.lastWorkout} value={pending ? '-' : lastWorkoutLabel(a.lastWorkoutAt)} />
      <Cell
        label={m.last7Days}
        value={pending ? '-' : m.sessions(a.workoutsLast7Days)}
        highlight={a.workoutsLast7Days > 0}
      />
    </li>
  )
}

/** Su mobile mostra l'etichetta accanto al valore; da sm in su le etichette stanno nell'intestazione. */
function Cell({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <p className="flex items-baseline justify-between gap-3 text-sm sm:block">
      <span className="text-xs text-muted-foreground sm:hidden">{label}</span>
      <span className={cn('tabular-nums', highlight && 'font-medium text-primary')}>{value}</span>
    </p>
  )
}

function ListSkeleton() {
  return (
    <div className="divide-y overflow-hidden rounded-lg border" aria-hidden>
      {[0, 1].map((i) => (
        <div key={i} className="h-14 animate-pulse bg-muted/40" />
      ))}
    </div>
  )
}

function ErrorState({ onRetry }: { onRetry: () => void }) {
  return (
    <div
      role="alert"
      className="flex flex-wrap items-center gap-3 rounded-lg border border-destructive/40 p-4"
    >
      <WarningCircleIcon size={20} className="text-destructive" />
      <p className="flex-1">{m.loadError}</p>
      <Button variant="outline" onClick={onRetry}>
        {m.retry}
      </Button>
    </div>
  )
}

function EmptyState() {
  return (
    <div className="flex items-start gap-3 rounded-lg border border-dashed p-6">
      <UsersThreeIcon size={20} className="mt-0.5 text-muted-foreground" />
      <div className="space-y-1">
        <h2 className="text-sm font-semibold">{m.emptyTitle}</h2>
        <p className="max-w-prose text-muted-foreground">{m.emptyBody}</p>
      </div>
    </div>
  )
}
