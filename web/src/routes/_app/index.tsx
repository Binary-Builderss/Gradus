import { UsersThreeIcon, WarningCircleIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { InviteAthlete } from '@/components/athletes/InviteAthlete'
import { Steps } from '@/components/brand'
import { Button } from '@/components/ui/button'
import { type AthleteRow, athletesQuery } from '@/lib/athletes'
import { daysSince, initials } from '@/lib/athleteStats'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.athletes

export const Route = createFileRoute('/_app/')({
  component: AthletesPage,
})

function lastWorkoutLabel(iso: string | null) {
  if (!iso) return m.never
  const d = daysSince(iso, new Date())
  return d <= 0 ? m.today : d === 1 ? m.yesterday : m.daysAgo(d)
}

function AthletesPage() {
  const { user } = Route.useRouteContext()
  const { data, isPending, isError, refetch } = useQuery(athletesQuery(user.id))

  return (
    <section className="space-y-8">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <h1 className="font-display text-5xl font-bold uppercase">{m.title}</h1>
        <InviteAthlete />
      </div>
      {isPending ? (
        <ListSkeleton />
      ) : isError ? (
        <ErrorState onRetry={() => void refetch()} />
      ) : data.length === 0 ? (
        <EmptyState />
      ) : (
        <ul className="grid gap-3">
          {data.map((a) => (
            <AthleteItem key={a.id} athlete={a} />
          ))}
        </ul>
      )}
    </section>
  )
}

function AthleteItem({ athlete: a }: { athlete: AthleteRow }) {
  const pending = a.status === 'pending'
  return (
    <li className="grid grid-cols-[auto_1fr] items-center gap-x-4 gap-y-3 rounded-xl border bg-card p-4 sm:grid-cols-[auto_1fr_auto_auto] sm:gap-x-8 sm:px-6">
      <span
        aria-hidden
        className="grid size-12 place-items-center rounded-full bg-accent font-display text-lg font-semibold text-accent-foreground"
      >
        {initials(a.name)}
      </span>
      <div className="min-w-0">
        <p className="truncate text-base font-medium">
          {a.name}
          {a.isSelf && <span className="ml-2 text-sm font-normal text-muted-foreground">{m.self}</span>}
        </p>
        <p className="truncate text-sm text-muted-foreground">{pending ? m.pending : a.email}</p>
      </div>
      <Stat label={m.lastWorkout} value={pending ? '-' : lastWorkoutLabel(a.lastWorkoutAt)} />
      <Stat
        label={m.last7Days}
        value={pending ? '-' : m.sessions(a.workoutsLast7Days)}
        highlight={a.workoutsLast7Days > 0}
      />
    </li>
  )
}

function Stat({ label, value, highlight }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className="col-span-2 flex items-baseline justify-between gap-4 sm:col-span-1 sm:block sm:min-w-32 sm:text-right">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className={cn('font-display text-2xl font-semibold uppercase', highlight && 'text-primary')}>
        {value}
      </p>
    </div>
  )
}

function ListSkeleton() {
  return (
    <div className="grid gap-3" aria-hidden>
      {[0, 1].map((i) => (
        <div key={i} className="h-20 animate-pulse rounded-xl border bg-muted/50" />
      ))}
    </div>
  )
}

function ErrorState({ onRetry }: { onRetry: () => void }) {
  return (
    <div
      role="alert"
      className="flex flex-wrap items-center gap-4 rounded-xl border border-destructive/40 p-6"
    >
      <WarningCircleIcon size={24} className="text-destructive" />
      <p className="flex-1">{m.loadError}</p>
      <Button variant="outline" onClick={onRetry}>
        {m.retry}
      </Button>
    </div>
  )
}

function EmptyState() {
  return (
    <div className="relative overflow-hidden rounded-xl border bg-card p-8 sm:p-10">
      <Steps className="absolute right-8 bottom-8 hidden opacity-60 sm:flex" />
      <div className="relative max-w-md space-y-4">
        <span className="grid size-12 place-items-center rounded-lg bg-accent text-accent-foreground">
          <UsersThreeIcon size={26} weight="duotone" />
        </span>
        <h2 className="font-display text-2xl font-semibold uppercase">{m.emptyTitle}</h2>
        <p className="text-muted-foreground">{m.emptyBody}</p>
      </div>
    </div>
  )
}
