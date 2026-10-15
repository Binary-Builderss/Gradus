import { ArrowRightIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { currentWeek, lastWorkoutLabel } from '@/lib/athleteStats'
import { athletesQuery } from '@/lib/athletes'
import { sessionsQuery } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { doneWorkoutsQuery } from '@/lib/summary'

const m = messages.app.athleteDetail.overview
const athletes = messages.app.athletes
const dateFormat = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short' })

type Active = { id: string; name: string; start_date: string; weeks: number }

/** Colpo d'occhio sull'atleta: dove sta nel mesociclo attivo e quando si è allenato l'ultima volta. */
export function AthleteOverview({
  coachId,
  athleteId,
  mesocycle,
}: {
  coachId: string
  athleteId: string
  mesocycle: Active
}) {
  const sessions = useQuery(sessionsQuery(mesocycle.id))
  const done = useQuery(doneWorkoutsQuery(mesocycle.id))
  const athlete = useQuery(athletesQuery(coachId))
  const row = athlete.data?.find((a) => a.id === athleteId)
  const [now] = useState(() => new Date())

  const week = currentWeek(mesocycle.start_date, mesocycle.weeks, now)
  const total = (sessions.data?.length ?? 0) * mesocycle.weeks
  const count = done.data?.length ?? 0
  const percent = total > 0 ? Math.min(100, Math.round((count / total) * 100)) : 0

  return (
    <section className="grid gap-3 rounded-lg border bg-card p-4" aria-labelledby="athlete-overview">
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <h2 id="athlete-overview" className="text-xs font-medium text-muted-foreground">
            {m.title}
          </h2>
          <p className="truncate font-medium">
            {mesocycle.name}
            <span className="font-normal text-muted-foreground">
              {' · '}
              {week
                ? m.weekOf(week, mesocycle.weeks)
                : m.notStarted(dateFormat.format(new Date(mesocycle.start_date)))}
            </span>
          </p>
        </div>
        <Link
          to="/mesocicli/$mesocycleId"
          params={{ mesocycleId: mesocycle.id }}
          className="inline-flex shrink-0 items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        >
          {m.open}
          <ArrowRightIcon size={14} />
        </Link>
      </div>

      <dl className="grid gap-4 sm:grid-cols-3 sm:divide-x">
        <div className="grid gap-1.5">
          <dt className="text-xs text-muted-foreground">{m.done}</dt>
          <dd className="font-medium">
            {done.isSuccess && sessions.isSuccess ? m.doneOf(count, total) : '–'}
          </dd>
          <div
            role="progressbar"
            aria-label={m.done}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={percent}
            className="h-1.5 overflow-hidden rounded-full bg-muted"
          >
            <div className="h-full rounded-full bg-primary" style={{ width: `${percent}%` }} />
          </div>
        </div>
        <div className="grid content-start gap-1.5 sm:pl-4">
          <dt className="text-xs text-muted-foreground">{athletes.lastWorkout}</dt>
          <dd className="font-medium">{row ? lastWorkoutLabel(row.lastWorkoutAt) : '–'}</dd>
        </div>
        <div className="grid content-start gap-1.5 sm:pl-4">
          <dt className="text-xs text-muted-foreground">{athletes.last7Days}</dt>
          <dd className="font-medium">{row ? athletes.sessions(row.workoutsLast7Days) : '–'}</dd>
        </div>
      </dl>
      {done.isSuccess && count === 0 && <p className="text-muted-foreground">{m.none}</p>}
    </section>
  )
}
