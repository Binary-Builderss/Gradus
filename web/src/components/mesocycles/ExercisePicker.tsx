import { MagnifyingGlassIcon, XIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useEffect, useId, useRef, useState, type KeyboardEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { messages } from '@/lib/messages'
import { matchesSearch, MUSCLE_GROUPS, type MuscleGroup, muscleGroupOf } from '@/lib/slotRules'
import { exercisesQuery } from '@/lib/slots'
import { cn } from '@/lib/utils'

const m = messages.app.mesocycle.picker
const muscleNames = messages.app.exercises.muscleNames

export function ExercisePicker({
  coachId,
  onPick,
  onClose,
}: {
  coachId: string
  onPick: (exerciseId: string) => void
  onClose: () => void
}) {
  const listId = useId()
  const listRef = useRef<HTMLUListElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const [search, setSearch] = useState('')
  const [group, setGroup] = useState<MuscleGroup | null>(null)
  const [active, setActive] = useState(0)
  const exercises = useQuery(exercisesQuery(coachId))
  const results = (exercises.data ?? []).filter(
    (e) => matchesSearch(e.name, search) && (group === null || muscleGroupOf(e.muscles) === group),
  )
  // Si apre in fondo alla seduta: lo porta in vista.
  useEffect(() => {
    rootRef.current?.scrollIntoView?.({ block: 'nearest' })
  }, [])
  const current = Math.min(active, Math.max(0, results.length - 1))

  function move(to: number) {
    const next = Math.max(0, Math.min(results.length - 1, to))
    setActive(next)
    listRef.current?.children[next]?.scrollIntoView?.({ block: 'nearest' }) // jsdom non lo ha
  }

  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Escape') return onClose()
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      move(current + (e.key === 'ArrowDown' ? 1 : -1))
    } else if (e.key === 'Enter' && results[current]) {
      e.preventDefault()
      onPick(results[current].id)
    }
  }

  return (
    <div ref={rootRef} className="grid gap-3 rounded-lg border bg-background p-3">
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <MagnifyingGlassIcon
            size={20}
            className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted-foreground"
          />
          <Input
            autoFocus
            role="combobox"
            aria-expanded
            aria-controls={listId}
            aria-activedescendant={results[current] ? `${listId}-${results[current].id}` : undefined}
            aria-label={m.search}
            placeholder={m.search}
            value={search}
            onChange={(e) => {
              setSearch(e.target.value)
              setActive(0)
            }}
            onKeyDown={onKeyDown}
            className="h-10 pl-10"
          />
        </div>
        <Button type="button" variant="ghost" size="icon-lg" aria-label={m.close} onClick={onClose}>
          <XIcon />
        </Button>
      </div>

      <div role="group" aria-label={m.groupFilter} className="flex flex-wrap gap-1.5">
        {[null, ...MUSCLE_GROUPS].map((g) => (
          <button
            key={g ?? 'all'}
            type="button"
            aria-pressed={group === g}
            onClick={() => {
              setGroup(g)
              setActive(0)
            }}
            className={cn(
              'h-8 rounded-md border px-3 text-sm font-medium text-muted-foreground transition-colors outline-none hover:bg-muted hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50',
              group === g && 'border-primary/50 bg-accent text-accent-foreground hover:bg-accent',
            )}
          >
            {g === null ? m.all : m.groups[g]}
          </button>
        ))}
      </div>

      {exercises.isPending ? (
        <div aria-hidden className="h-24 animate-pulse rounded-md bg-muted/50" />
      ) : exercises.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : results.length === 0 ? (
        <div className="grid justify-items-start gap-1 px-1 py-2">
          <p className="font-medium">{m.none}</p>
          <p className="text-muted-foreground">{m.noneHint}</p>
          <Link to="/esercizi" className="text-primary underline-offset-4 hover:underline">
            {m.library}
          </Link>
        </div>
      ) : (
        <>
          <ul
            ref={listRef}
            id={listId}
            role="listbox"
            aria-label={m.search}
            className="max-h-80 overflow-y-auto"
          >
            {results.map((e, i) => (
              <li
                key={e.id}
                id={`${listId}-${e.id}`}
                role="option"
                aria-selected={i === current}
                onMouseMove={() => i !== current && setActive(i)}
                onClick={() => onPick(e.id)}
                className={cn(
                  'flex cursor-pointer items-center gap-3 rounded-md px-3 py-2',
                  i === current && 'bg-muted',
                )}
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">{e.name}</p>
                  {e.muscles.length > 0 && (
                    <p className="truncate text-xs text-muted-foreground">
                      {e.muscles
                        .slice(0, 2)
                        .map((x) => muscleNames[x.muscle])
                        .join(', ')}
                    </p>
                  )}
                </div>
                {e.owner_id !== null && (
                  <span className="rounded border px-1.5 py-px text-xs text-muted-foreground">{m.mine}</span>
                )}
              </li>
            ))}
          </ul>
          <p className="px-1 text-xs text-muted-foreground">{m.count(results.length)}</p>
        </>
      )}
    </div>
  )
}
