import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { fieldErrors } from '@/lib/auth'
import { fromTemplateSchema, newMesocycleSchema } from '@/lib/mesocycleSchema'
import { createMesocycle } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { createFromTemplate, templatesQuery } from '@/lib/templates'

const m = messages.app.athleteDetail

export function NewMesocycleForm({
  coachId,
  athleteId,
  onCancel,
}: {
  coachId: string
  athleteId: string
  onCancel: () => void
}) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const templates = useQuery(templatesQuery(coachId))
  const [templateId, setTemplateId] = useState('')
  const template = templates.data?.find((t) => t.id === templateId)
  const create = useMutation({
    mutationFn: (
      values: Parameters<typeof createMesocycle>[1] | { template: string; start_date: string; name: string },
    ) =>
      'template' in values
        ? createFromTemplate(values.template, athleteId, { start_date: values.start_date, name: values.name })
        : createMesocycle(athleteId, values),
    onSuccess: async (id) => {
      await queryClient.invalidateQueries({ queryKey: ['mesocycles', athleteId] })
      await navigate({ to: '/mesocicli/$mesocycleId', params: { mesocycleId: id } })
    },
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = Object.fromEntries(new FormData(event.currentTarget))
    if (template) {
      const fromTemplate = fromTemplateSchema.safeParse(form)
      if (!fromTemplate.success) return setErrors(fieldErrors(fromTemplate.error))
      setErrors({})
      return create.mutate({ template: template.id, ...fromTemplate.data })
    }
    const parsed = newMesocycleSchema.safeParse(form)
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    create.mutate(parsed.data)
  }

  return (
    <form noValidate onSubmit={submit} className="grid gap-4 rounded-lg border bg-card p-4">
      {templates.data && templates.data.length > 0 && (
        <div className="grid max-w-sm gap-2">
          <Label htmlFor="meso-template">{m.fromTemplate}</Label>
          <select
            id="meso-template"
            value={templateId}
            onChange={(e) => {
              setTemplateId(e.target.value)
              setErrors({})
            }}
            className="h-9 rounded-md border bg-background px-2 text-sm dark:bg-input/30"
          >
            <option value="">{m.scratch}</option>
            {templates.data.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
        </div>
      )}
      <div className="grid gap-4 sm:grid-cols-[1fr_11rem_7rem]">
        <Field
          id="meso-name"
          name="name"
          label={m.name}
          error={errors.name}
          placeholder={template?.name}
          autoFocus
        />
        <Field id="meso-start" name="start_date" type="date" label={m.startDate} error={errors.start_date} />
        {template ? (
          <div className="grid gap-2">
            <Label>{m.weeks}</Label>
            <p
              className="flex h-9 items-center text-sm text-muted-foreground"
              title={m.templateWeeks(template.weeks)}
            >
              {template.weeks}
            </p>
          </div>
        ) : (
          <Field
            id="meso-weeks"
            name="weeks"
            type="number"
            label={m.weeks}
            defaultValue="8"
            error={errors.weeks}
          />
        )}
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
