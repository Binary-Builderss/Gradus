import { GearSixIcon } from '@phosphor-icons/react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle
const label = messages.app.athleteDetail.weeks

/** Settimane e scarico in una riga di riepilogo; i controlli si aprono solo a richiesta. */
export function MesocycleSettings({
  weeks,
  deloadWeeks,
  onWeeks,
  onToggleDeload,
}: {
  weeks: number
  deloadWeeks: readonly number[]
  onWeeks: (weeks: number) => void
  onToggleDeload: (week: number) => void
}) {
  const [open, setOpen] = useState(false)
  return (
    <div className="grid gap-3">
      <div
        className="flex w-fit flex-wrap items-center gap-2 text-sm text-muted-foreground"
        data-tour="meso-settings"
      >
        <span>{m.settings.summary(weeks, deloadWeeks)}</span>
        <Button
          variant="ghost"
          size="sm"
          aria-expanded={open}
          aria-controls="mesocycle-settings"
          onClick={() => setOpen(!open)}
        >
          <GearSixIcon data-icon="inline-start" />
          {open ? m.settings.close : m.settings.edit}
        </Button>
      </div>
      {open && (
        <div
          id="mesocycle-settings"
          className="grid gap-4 rounded-lg border bg-card p-3 sm:grid-cols-[auto_1fr] sm:items-start sm:gap-x-8"
        >
          <label className="grid gap-1.5 text-xs text-muted-foreground">
            {label}
            <Input
              key={weeks}
              type="number"
              min={1}
              max={52}
              defaultValue={weeks}
              onBlur={(e) => {
                const next = Number(e.target.value)
                if (Number.isInteger(next) && next >= 1 && next <= 52 && next !== weeks) onWeeks(next)
                else e.target.value = String(weeks)
              }}
              className="h-8 w-20 text-sm"
            />
          </label>
          <div className="grid gap-1.5">
            <h2 className="text-xs text-muted-foreground">{m.deload}</h2>
            <ul className="flex flex-wrap gap-1">
              {Array.from({ length: weeks }, (_, i) => i + 1).map((week) => {
                const on = deloadWeeks.includes(week)
                return (
                  <li key={week}>
                    <button
                      type="button"
                      aria-pressed={on}
                      onClick={() => onToggleDeload(week)}
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
        </div>
      )}
    </div>
  )
}
