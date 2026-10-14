import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { fieldErrors } from '@/lib/auth'
import { newMesocycleSchema } from '@/lib/mesocycleSchema'
import { createMesocycle } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'

const m = messages.app.athleteDetail

export function NewMesocycleForm({ athleteId, onCancel }: { athleteId: string; onCancel: () => void }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const create = useMutation({
    mutationFn: (values: Parameters<typeof createMesocycle>[1]) => createMesocycle(athleteId, values),
    onSuccess: async (id) => {
      await queryClient.invalidateQueries({ queryKey: ['mesocycles', athleteId] })
      await navigate({ to: '/mesocicli/$mesocycleId', params: { mesocycleId: id } })
    },
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const parsed = newMesocycleSchema.safeParse(Object.fromEntries(new FormData(event.currentTarget)))
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    create.mutate(parsed.data)
  }

  return (
    <form noValidate onSubmit={submit} className="grid gap-4 rounded-lg border bg-card p-4">
      <div className="grid gap-4 sm:grid-cols-[1fr_11rem_7rem]">
        <Field id="meso-name" name="name" label={m.name} error={errors.name} autoFocus />
        <Field id="meso-start" name="start_date" type="date" label={m.startDate} error={errors.start_date} />
        <Field
          id="meso-weeks"
          name="weeks"
          type="number"
          label={m.weeks}
          defaultValue="8"
          error={errors.weeks}
        />
      </div>
      {create.isError && (
        <p role="alert" className="text-sm text-destructive">
          {messages.app.mesocycle.errors.generic}
        </p>
      )}
      <div className="flex gap-2">
        <Button type="submit" disabled={create.isPending}>
          {create.isPending ? m.creating : m.create}
        </Button>
        <Button type="button" variant="ghost" onClick={onCancel}>
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
  ...input
}: { id: string; label: string; error?: string } & React.ComponentProps<'input'>) {
  return (
    <div className="grid gap-2">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${id}-error` : undefined}
        className="h-9 text-sm"
        {...input}
      />
      {error && (
        <p id={`${id}-error`} className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  )
}
