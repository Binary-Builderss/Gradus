import { CopyIcon, PencilSimpleIcon, PlayCircleIcon, PlusIcon, TrashIcon } from '@phosphor-icons/react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { ExerciseForm } from '@/components/exercises/ExerciseForm'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { deleteExercise, type LibraryExercise, libraryQuery } from '@/lib/library'
import { messages } from '@/lib/messages'
import { matchesSearch } from '@/lib/slotRules'

const m = messages.app.exercises

export const Route = createFileRoute('/_app/esercizi')({
  component: ExercisesPage,
})

type Editing = { mode: 'new' } | { mode: 'edit'; id: string } | { mode: 'copy'; source: LibraryExercise }

function ExercisesPage() {
  const { user } = Route.useRouteContext()
  const queryClient = useQueryClient()
  const library = useQuery(libraryQuery(user.id))
  const [search, setSearch] = useState('')
  const [onlyMine, setOnlyMine] = useState(false)
  const [editing, setEditing] = useState<Editing | null>(null)
  const remove = useMutation({
    mutationFn: (id: string) => deleteExercise(user.id, id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['exercises'] }),
  })

  const list = (library.data ?? []).filter((e) => (!onlyMine || e.owner_id) && matchesSearch(e.name, search))
  const close = () => setEditing(null)

  return (
    <section className="space-y-8">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <h1 className="font-display text-5xl font-bold uppercase">{m.title}</h1>
        {!editing && (
          <Button size="lg" onClick={() => setEditing({ mode: 'new' })}>
            <PlusIcon data-icon="inline-start" />
            {m.newExercise}
          </Button>
        )}
      </div>

      {editing && editing.mode !== 'edit' && (
        <ExerciseForm
          key={editing.mode === 'copy' ? editing.source.id : 'new'}
          coachId={user.id}
          seed={
            editing.mode === 'copy'
              ? { ...editing.source, name: `${editing.source.name} (copia)` }
              : undefined
          }
          onDone={close}
        />
      )}

      <div className="flex flex-wrap items-center gap-4">
        <Input
          aria-label={m.search}
          placeholder={m.search}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="h-11 max-w-sm flex-1 text-base"
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={onlyMine}
            onChange={(e) => setOnlyMine(e.target.checked)}
            className="size-4 accent-primary"
          />
          {m.onlyMine}
        </label>
      </div>

      {library.isPending ? (
        <div aria-hidden className="h-40 animate-pulse rounded-xl border bg-muted/50" />
      ) : library.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : list.length === 0 ? (
        <p className="text-muted-foreground">{m.empty}</p>
      ) : (
        <ul className="grid gap-3">
          {list.map((e) =>
            editing?.mode === 'edit' && editing.id === e.id ? (
              <li key={e.id}>
                <ExerciseForm coachId={user.id} exercise={e} onDone={close} />
              </li>
            ) : (
              <ExerciseItem
                key={e.id}
                exercise={e}
                onEdit={() => setEditing({ mode: 'edit', id: e.id })}
                onCopy={() => setEditing({ mode: 'copy', source: e })}
                onRemove={() => remove.mutate(e.id)}
              />
            ),
          )}
        </ul>
      )}
    </section>
  )
}

function ExerciseItem({
  exercise: e,
  onEdit,
  onCopy,
  onRemove,
}: {
  exercise: LibraryExercise
  onEdit: () => void
  onCopy: () => void
  onRemove: () => void
}) {
  const own = e.owner_id !== null
  return (
    <li className="grid gap-3 rounded-xl border bg-card p-4 sm:px-6">
      <div className="flex flex-wrap items-center gap-3">
        <p className="min-w-0 flex-1 font-medium">{e.name}</p>
        <span className="rounded-full border px-3 py-1 text-xs font-medium text-muted-foreground">
          {own ? m.mine : m.catalog}
        </span>
        {e.video_url && (
          <Button variant="ghost" size="icon" aria-label={m.watchVideo} asChild>
            <a href={e.video_url} target="_blank" rel="noopener noreferrer">
              <PlayCircleIcon />
            </a>
          </Button>
        )}
        {own ? (
          <>
            <Button variant="ghost" size="icon" aria-label={m.edit} title={m.edit} onClick={onEdit}>
              <PencilSimpleIcon />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              aria-label={m.remove}
              title={`${m.remove}. ${m.removeHint}`}
              onClick={onRemove}
            >
              <TrashIcon />
            </Button>
          </>
        ) : (
          <Button variant="outline" onClick={onCopy} title={m.duplicateHint}>
            <CopyIcon data-icon="inline-start" />
            {m.duplicate}
          </Button>
        )}
      </div>
      <ul className="flex flex-wrap gap-2">
        {e.muscles.map((x) => (
          <li key={x.muscle} className="rounded-md bg-muted px-2.5 py-1 text-xs">
            {m.muscleNames[x.muscle]}{' '}
            <span className="font-medium tabular-nums">{String(x.weight).replace('.', ',')}</span>
          </li>
        ))}
      </ul>
      {e.notes && <p className="text-sm text-muted-foreground">{e.notes}</p>}
    </li>
  )
}
