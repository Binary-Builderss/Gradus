import { PlusIcon, XIcon } from '@phosphor-icons/react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { exerciseSchema, MUSCLES, type Muscle } from '@/lib/exerciseForm'
import { createExercise, type LibraryExercise, updateExercise } from '@/lib/library'
import { messages } from '@/lib/messages'

const m = messages.app.exercises

type MuscleRow = { muscle: Muscle; weight: string }

const toRows = (list: LibraryExercise['muscles']): MuscleRow[] =>
  list.map((x) => ({ muscle: x.muscle, weight: String(x.weight) }))

/** Crea un esercizio proprio o modifica l'esistente (`exercise`); `seed` precompila una copia. */
export function ExerciseForm({
  coachId,
  exercise,
  seed,
  onDone,
}: {
  coachId: string
  exercise?: LibraryExercise
  seed?: Omit<LibraryExercise, 'id' | 'owner_id'>
  onDone: () => void
}) {
  const queryClient = useQueryClient()
  const source = exercise ?? seed
  const [rows, setRows] = useState<MuscleRow[]>(
    source ? toRows(source.muscles) : [{ muscle: 'chest', weight: '1' }],
  )
  const [errors, setErrors] = useState<Partial<Record<'name' | 'video_url' | 'muscles', string>>>({})

  const save = useMutation({
    mutationFn: (input: ReturnType<typeof exerciseSchema.parse>) =>
      exercise ? updateExercise(coachId, exercise, input) : createExercise(coachId, input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['exercises'] })
      onDone()
    },
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const f = new FormData(event.currentTarget)
    const parsed = exerciseSchema.safeParse({
      name: f.get('name'),
      video_url: f.get('video_url'),
      notes: f.get('notes'),
      muscles: rows.map((r) => ({ muscle: r.muscle, weight: Number(r.weight.replace(',', '.')) })),
    })
    if (!parsed.success) {
      const next: typeof errors = {}
      for (const issue of parsed.error.issues) {
        const key = issue.path[0] === 'muscles' ? 'muscles' : (issue.path[0] as 'name' | 'video_url')
        next[key] ??= issue.message
      }
      return setErrors(next)
    }
    setErrors({})
    save.mutate(parsed.data)
  }

  const setRow = (i: number, patch: Partial<MuscleRow>) =>
    setRows((list) => list.map((r, j) => (j === i ? { ...r, ...patch } : r)))
  const free = MUSCLES.filter((x) => !rows.some((r) => r.muscle === x))

  return (
    <form noValidate onSubmit={submit} className="grid gap-5 rounded-xl border bg-card p-4 sm:p-6">
      <Field id="ex-name" label={m.name} error={errors.name}>
        <Input
          id="ex-name"
          name="name"
          autoFocus
          defaultValue={source?.name ?? ''}
          className="h-11 text-base"
        />
      </Field>
      <Field id="ex-video" label={m.video} error={errors.video_url}>
        <Input
          id="ex-video"
          name="video_url"
          type="url"
          inputMode="url"
          defaultValue={source?.video_url ?? ''}
          className="h-11 text-base"
        />
      </Field>
      <Field id="ex-notes" label={m.notes}>
        <textarea
          id="ex-notes"
          name="notes"
          rows={3}
          defaultValue={source?.notes ?? ''}
          className="w-full rounded-lg border bg-background px-3 py-2 text-base dark:bg-input/30"
        />
      </Field>

      <fieldset className="grid gap-3">
        <legend className="text-sm font-medium">{m.muscles}</legend>
        <p className="text-xs text-muted-foreground">{m.musclesHint}</p>
        <ul className="grid gap-2">
          {rows.map((r, i) => (
            <li key={r.muscle} className="flex items-center gap-2">
              <select
                aria-label={m.muscles}
                value={r.muscle}
                onChange={(e) => setRow(i, { muscle: e.target.value as Muscle })}
                className="h-10 flex-1 rounded-lg border bg-background px-2 text-sm dark:bg-input/30"
              >
                {[r.muscle, ...free].map((x) => (
                  <option key={x} value={x}>
                    {m.muscleNames[x]}
                  </option>
                ))}
              </select>
              <Input
                aria-label={m.weight}
                type="number"
                inputMode="decimal"
                min={0.05}
                max={1}
                step={0.05}
                value={r.weight}
                onChange={(e) => setRow(i, { weight: e.target.value })}
                className="h-10 w-24 text-base"
              />
              <Button
                type="button"
                variant="ghost"
                size="icon"
                aria-label={m.removeMuscle}
                onClick={() => setRows((list) => list.filter((_, j) => j !== i))}
              >
                <XIcon />
              </Button>
            </li>
          ))}
        </ul>
        {errors.muscles && (
          <p role="alert" className="text-sm text-destructive">
            {errors.muscles}
          </p>
        )}
        {free.length > 0 && (
          <Button
            type="button"
            variant="outline"
            className="justify-self-start"
            onClick={() => setRows((list) => [...list, { muscle: free[0]!, weight: '0.5' }])}
          >
            <PlusIcon data-icon="inline-start" />
            {m.addMuscle}
          </Button>
        )}
      </fieldset>

      {save.isError && (
        <p role="alert" className="text-sm text-destructive">
          {m.errors.generic}
        </p>
      )}
      <div className="flex gap-2">
        <Button type="submit" size="lg" disabled={save.isPending}>
          {save.isPending ? m.saving : m.save}
        </Button>
        <Button type="button" variant="ghost" size="lg" onClick={onDone}>
          {m.cancel}
        </Button>
      </div>
    </form>
  )
}

function Field({
  id,
  label,
  error,
  children,
}: {
  id: string
  label: string
  error?: string
  children: React.ReactNode
}) {
  return (
    <div className="grid gap-2">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {error && (
        <p id={`${id}-error`} role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  )
}
