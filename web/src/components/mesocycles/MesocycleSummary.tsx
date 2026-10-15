import { CheckIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { buildGridRows, type BlockData, type WeekData, weekSetTotals } from '@/lib/gridModel'
import { messages } from '@/lib/messages'
import type { GroupRow, SlotRow } from '@/lib/slots'
import {
  buildProgressTable,
  buildVolumeTable,
  doneWorkoutsQuery,
  exerciseProgressQuery,
  formatChange,
  formatVolume,
  heatPercent,
  weeklyVolumeQuery,
} from '@/lib/summary'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle.summary
const muscleNames = messages.app.exercises.muscleNames

const headCell =
  'border-r px-2 py-1.5 text-center font-mono text-xs font-medium text-muted-foreground last:border-r-0'
const stickyHead =
  'sticky left-0 z-[1] w-44 border-r bg-muted px-3 py-1.5 text-left text-xs font-medium text-muted-foreground'

export function MesocycleSummary({
  mesocycleId,
  totalWeeks,
  deloadWeeks,
  sessions,
  groups,
  slots,
  blocks,
  weeks,
}: {
  mesocycleId: string
  totalWeeks: number
  deloadWeeks: readonly number[]
  sessions: readonly { id: string; name: string }[]
  groups: readonly GroupRow[]
  slots: readonly SlotRow[]
  blocks: readonly BlockData[]
  weeks: readonly WeekData[]
}) {
  const volume = useQuery(weeklyVolumeQuery(mesocycleId))
  const done = useQuery(doneWorkoutsQuery(mesocycleId))
  const progress = useQuery(exerciseProgressQuery(mesocycleId))
  const weekNumbers = Array.from({ length: totalWeeks }, (_, i) => i + 1)
  const doneKeys = new Set((done.data ?? []).map((w) => `${w.session_id}:${w.week}`))

  const perSession = sessions.map((s) => ({
    ...s,
    sets: weekSetTotals(buildGridRows(s.id, groups, slots, blocks, weeks), totalWeeks),
  }))
  const weekTotals = weekNumbers.map((_, i) => perSession.reduce((sum, s) => sum + s.sets[i]!, 0))

  const progressTable = buildProgressTable(progress.data ?? [], totalWeeks)
  const hasProgress = progressTable.some((e) => e.bestE1rm !== null || e.weeks.some((w) => w.setsDone > 0))
  const table = buildVolumeTable(volume.data ?? [], totalWeeks)
  const max = Math.max(0, ...table.flatMap((t) => t.weeks.map((w) => w.prescribed)))

  const weekHead = (week: number) => (
    <th
      key={week}
      scope="col"
      className={cn(headCell, deloadWeeks.includes(week) && 'bg-warning text-warning-foreground')}
    >
      {messages.app.mesocycle.weekShort(week)}
      {deloadWeeks.includes(week) && (
        <span className="block font-sans text-xs font-normal">
          {messages.app.mesocycle.grid.weekState.deload}
        </span>
      )}
    </th>
  )

  return (
    <div className="grid gap-8">
      <section className="grid gap-2" aria-labelledby="summary-sessions">
        <div>
          <h2 id="summary-sessions" className="text-sm font-semibold">
            {m.sessionsTitle}
          </h2>
          <p className="text-muted-foreground">{m.sessionsHint}</p>
        </div>
        {perSession.length === 0 ? (
          <p className="rounded-lg border border-dashed p-4 text-muted-foreground">{m.noSessions}</p>
        ) : (
          <div className="overflow-x-auto rounded-md border bg-card">
            <table className="w-full min-w-[36rem] table-fixed border-collapse text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  <th scope="col" className={stickyHead}>
                    {m.session}
                  </th>
                  {weekNumbers.map(weekHead)}
                </tr>
              </thead>
              <tbody>
                {perSession.map((s) => (
                  <tr key={s.id} className="border-b">
                    <th
                      scope="row"
                      className="sticky left-0 z-[1] border-r bg-card px-3 py-1.5 text-left font-medium"
                    >
                      {s.name}
                    </th>
                    {weekNumbers.map((week) => {
                      const sets = s.sets[week - 1]!
                      const executed = doneKeys.has(`${s.id}:${week}`)
                      return (
                        <td
                          key={week}
                          className={cn(
                            'border-r px-2 py-1.5 text-center font-mono text-xs tabular-nums last:border-r-0',
                            deloadWeeks.includes(week) && 'bg-warning/60',
                            executed && 'bg-hatch',
                          )}
                        >
                          <span className="inline-flex items-center justify-center gap-1">
                            {sets || <span className="text-muted-foreground">–</span>}
                            {executed && (
                              <>
                                <CheckIcon size={12} weight="bold" className="text-primary" aria-hidden />
                                <span className="sr-only">{m.executed}</span>
                              </>
                            )}
                          </span>
                        </td>
                      )
                    })}
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="bg-muted/50">
                  <th scope="row" className={stickyHead}>
                    {m.weekTotal}
                  </th>
                  {weekTotals.map((total, i) => (
                    <td
                      key={i}
                      className="border-r px-2 py-1.5 text-center font-mono text-xs font-medium tabular-nums last:border-r-0"
                    >
                      {total || ''}
                    </td>
                  ))}
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </section>

      <section className="grid gap-2" aria-labelledby="summary-progress">
        <div>
          <h2 id="summary-progress" className="text-sm font-semibold">
            {m.progressTitle}
          </h2>
          <p className="max-w-prose text-muted-foreground">{m.progressHint}</p>
        </div>
        {progress.isError ? (
          <p role="alert" className="text-destructive">
            {m.progressError}
          </p>
        ) : progress.isSuccess && !hasProgress ? (
          <p className="rounded-lg border border-dashed p-4 text-muted-foreground">{m.noProgress}</p>
        ) : (
          <div className="overflow-x-auto rounded-md border bg-card">
            <table className="w-full min-w-[36rem] table-fixed border-collapse text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  <th scope="col" className={stickyHead}>
                    {m.exercise}
                  </th>
                  {weekNumbers.map(weekHead)}
                  <th scope="col" className={cn(headCell, 'w-28 border-l')}>
                    {m.estimatedMax}
                  </th>
                </tr>
              </thead>
              <tbody>
                {progressTable.map((e) => (
                  <tr key={e.exerciseId} className="border-b last:border-b-0">
                    <th
                      scope="row"
                      className="sticky left-0 z-[1] border-r bg-card px-3 py-1.5 text-left font-medium"
                    >
                      {e.name}
                    </th>
                    {e.weeks.map((w, i) => (
                      <td
                        key={i}
                        className={cn(
                          'border-r px-2 py-1.5 text-center font-mono text-xs tabular-nums',
                          deloadWeeks.includes(i + 1) && 'bg-warning/60',
                        )}
                      >
                        {w.setsDone > 0 ? (
                          <>
                            {w.topLoadKg !== null && w.topReps !== null ? (
                              `${formatVolume(w.topLoadKg)} × ${w.topReps}`
                            ) : (
                              <span className="text-muted-foreground">–</span>
                            )}
                            <span className="block text-xs font-normal text-muted-foreground">
                              {m.setsOf(w.setsDone, w.setsPrescribed)}
                            </span>
                          </>
                        ) : (
                          <span className="text-muted-foreground">–</span>
                        )}
                      </td>
                    ))}
                    <td className="border-l px-2 py-1.5 text-center font-mono text-xs tabular-nums">
                      {e.bestE1rm !== null ? (
                        <>
                          <span className="font-medium">{formatVolume(e.bestE1rm)} kg</span>
                          {e.e1rmChange !== null && (
                            <span className="block text-xs text-muted-foreground">
                              {formatChange(e.e1rmChange)} kg
                            </span>
                          )}
                        </>
                      ) : (
                        <span className="text-muted-foreground">–</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid gap-2" aria-labelledby="summary-volume">
        <div>
          <h2 id="summary-volume" className="text-sm font-semibold">
            {m.volumeTitle}
          </h2>
          <p className="max-w-prose text-muted-foreground">{m.volumeHint}</p>
        </div>
        {volume.isError ? (
          <p role="alert" className="text-destructive">
            {m.volumeError}
          </p>
        ) : volume.isSuccess && table.length === 0 ? (
          <p className="rounded-lg border border-dashed p-4 text-muted-foreground">{m.noVolume}</p>
        ) : (
          <div className="overflow-x-auto rounded-md border bg-card">
            <table className="w-full min-w-[36rem] table-fixed border-collapse text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  <th scope="col" className={stickyHead}>
                    {m.muscle}
                  </th>
                  {weekNumbers.map(weekHead)}
                  <th scope="col" className={cn(headCell, 'border-l')}>
                    {m.total}
                  </th>
                </tr>
              </thead>
              <tbody>
                {table.map((t) => (
                  <tr key={t.muscle} className="border-b last:border-b-0">
                    <th
                      scope="row"
                      className="sticky left-0 z-[1] border-r bg-card px-3 py-1.5 text-left font-medium"
                    >
                      {muscleNames[t.muscle]}
                    </th>
                    {t.weeks.map((w, i) => (
                      <td
                        key={i}
                        className="border-r px-2 py-1.5 text-center font-mono text-xs tabular-nums"
                        style={{
                          backgroundColor: w.prescribed
                            ? `color-mix(in oklch, var(--primary) ${heatPercent(w.prescribed, max)}%, transparent)`
                            : undefined,
                        }}
                      >
                        {w.prescribed ? (
                          formatVolume(w.prescribed)
                        ) : (
                          <span className="text-muted-foreground">–</span>
                        )}
                        {w.executed > 0 && (
                          <span className="block text-xs font-normal text-muted-foreground">
                            {m.executedSets(formatVolume(w.executed))}
                          </span>
                        )}
                      </td>
                    ))}
                    <td className="border-l px-2 py-1.5 text-center font-mono text-xs font-medium tabular-nums">
                      {formatVolume(t.total)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  )
}
