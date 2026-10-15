import { CaretRightIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { messages } from '@/lib/messages'
import { bestSetsQuery, type TopSetPoint, topSetHistoryQuery } from '@/lib/topSets'
import { cn } from '@/lib/utils'

const m = messages.app.athleteDetail.bestSets
const number = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1 })
const date = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short', year: 'numeric' })
const day = (iso: string) => date.format(new Date(`${iso}T12:00:00`))

/** La miglior serie di ogni esercizio dell'atleta (tra tutti i mesocicli), con lo storico seduta per seduta. */
export function BestSets({ coachId, athleteId }: { coachId: string; athleteId: string }) {
  const best = useQuery(bestSetsQuery(coachId, athleteId))
  const [open, setOpen] = useState<string | null>(null)

  return (
    <section className="space-y-2" data-tour="best-sets">
      <div className="grid gap-0.5">
        <h2 className="text-sm font-semibold">{m.title}</h2>
        <p className="max-w-prose text-xs text-muted-foreground">{m.hint}</p>
      </div>
      {best.isPending ? (
        <div aria-hidden className="h-14 animate-pulse rounded-lg border bg-muted/40" />
      ) : best.isError ? (
        <p role="alert" className="text-sm text-destructive">
          {m.loadError}
        </p>
      ) : best.data.length === 0 ? (
        <p className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">{m.empty}</p>
      ) : (
        <ul className="divide-y overflow-hidden rounded-lg border bg-card">
          {best.data.map((s) => {
            const expanded = open === s.exercise_id
            return (
              <li key={s.exercise_id}>
                <button
                  type="button"
                  aria-expanded={expanded}
                  aria-label={(expanded ? m.hide : m.show)(s.exercise_name)}
                  onClick={() => setOpen(expanded ? null : s.exercise_id)}
                  className="grid w-full grid-cols-[auto_1fr] items-center gap-x-3 gap-y-0.5 px-4 py-2.5 text-left transition-colors outline-none hover:bg-muted/50 focus-visible:bg-muted/50 sm:grid-cols-[auto_1fr_9rem_9rem_11rem]"
                >
                  <CaretRightIcon
                    size={14}
                    className={cn('text-muted-foreground transition-transform', expanded && 'rotate-90')}
                  />
                  <span className="min-w-0 truncate font-medium">{s.exercise_name}</span>
                  <span className="col-start-2 text-sm tabular-nums sm:col-start-auto">
                    <span className="text-xs text-muted-foreground sm:hidden">{m.best}: </span>
                    {m.set(number.format(s.best_load_kg), s.best_reps)}
                  </span>
                  <span className="col-start-2 text-sm font-medium tabular-nums sm:col-start-auto">
                    <span className="text-xs font-normal text-muted-foreground sm:hidden">{m.e1rm}: </span>
                    {m.kg(number.format(s.best_e1rm))}
                  </span>
                  <span className="col-start-2 text-xs text-muted-foreground sm:col-start-auto sm:text-right">
                    {m.workoutsCount(s.workouts)} · {day(s.last_on)}
                  </span>
                </button>
                {expanded && (
                  <History athleteId={athleteId} exerciseId={s.exercise_id} name={s.exercise_name} />
                )}
              </li>
            )
          })}
        </ul>
      )}
    </section>
  )
}

function History({ athleteId, exerciseId, name }: { athleteId: string; exerciseId: string; name: string }) {
  const history = useQuery(topSetHistoryQuery(athleteId, exerciseId))
  return (
    <div className="border-t bg-muted/30 px-4 py-3" role="region" aria-label={m.historyTitle(name)}>
      {history.isPending ? (
        <div aria-hidden className="h-10 animate-pulse rounded-md bg-muted/60" />
      ) : history.isError ? (
        <p role="alert" className="text-sm text-destructive">
          {m.historyError}
        </p>
      ) : history.data.length === 0 ? (
        <p className="text-sm text-muted-foreground">{m.historyEmpty}</p>
      ) : (
        <HistoryList points={history.data} />
      )}
    </div>
  )
}

/** Una riga per seduta; la barra confronta il massimale stimato con il migliore dello storico. */
function HistoryList({ points }: { points: TopSetPoint[] }) {
  const max = Math.max(...points.map((p) => p.e1rm))
  return (
    <ul className="grid gap-1.5 text-sm">
      {points.map((p) => (
        <li
          key={p.workout_id}
          className="grid grid-cols-[6.5rem_1fr_auto] items-center gap-x-3 gap-y-0.5 sm:grid-cols-[6.5rem_5rem_8rem_1fr_6rem]"
        >
          <span className="text-muted-foreground">{day(p.performed_on)}</span>
          <span className="hidden text-xs text-muted-foreground sm:inline">{m.week(p.week)}</span>
          <span className="tabular-nums">{m.set(number.format(p.load_kg), p.reps)}</span>
          <span aria-hidden className="hidden h-1.5 rounded-full bg-muted sm:block">
            <span
              className="block h-full rounded-full bg-primary/70"
              style={{ width: `${Math.max(4, (p.e1rm / max) * 100)}%` }}
            />
          </span>
          <span className="text-right font-medium tabular-nums">{m.kg(number.format(p.e1rm))}</span>
        </li>
      ))}
    </ul>
  )
}
