import { MagnifyingGlassIcon, XIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { exercisesQuery } from '@/lib/slots'
import { matchesSearch } from '@/lib/slotRules'
import { messages } from '@/lib/messages'

const m = messages.app.mesocycle.picker

export function ExercisePicker({
  coachId,
  onPick,
  onClose,
}: {
  coachId: string
  onPick: (exerciseId: string) => void
  onClose: () => void
}) {
  const [search, setSearch] = useState('')
  const exercises = useQuery(exercisesQuery(coachId))
  const results = (exercises.data ?? []).filter((e) => matchesSearch(e.name, search)).slice(0, 50)

  return (
    <div className="grid gap-2 rounded-lg border bg-background p-3">
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <MagnifyingGlassIcon
            size={18}
            className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted-foreground"
          />
          <Input
            autoFocus
            aria-label={m.search}
            placeholder={m.search}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Escape' && onClose()}
            className="h-9 pl-10 text-sm"
          />
        </div>
        <Button type="button" variant="ghost" size="icon" aria-label={m.close} onClick={onClose}>
          <XIcon />
        </Button>
      </div>
      {exercises.isPending ? (
        <div aria-hidden className="h-24 animate-pulse rounded-md bg-muted/50" />
      ) : exercises.isError ? (
        <p role="alert" className="text-sm text-destructive">
          {m.loadError}
        </p>
      ) : results.length === 0 ? (
        <p className="px-1 py-2 text-sm text-muted-foreground">{m.none}</p>
      ) : (
        <ul className="max-h-64 overflow-y-auto">
          {results.map((e) => (
            <li key={e.id}>
              <button
                type="button"
                onClick={() => onPick(e.id)}
                className="w-full rounded-md px-3 py-2 text-left text-sm transition-colors hover:bg-muted focus-visible:bg-muted focus-visible:outline-none"
              >
                {e.name}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
