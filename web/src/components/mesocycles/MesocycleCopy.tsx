import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useState, type FormEvent } from 'react'
import {
  Dialog,
  DialogCancel,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { fieldErrors } from '@/lib/auth'
import { duplicateMesocycleSchema, saveTemplateSchema } from '@/lib/mesocycleSchema'
import { cloneMesocycle } from '@/lib/mesocycles'
import { messages } from '@/lib/messages'
import { saveAsTemplate } from '@/lib/templates'

const m = messages.app.mesocycle.status
const copy = m.copy

type Target = { id: string; name: string; athlete_id: string }

/** Oggi nel fuso del browser, come `yyyy-mm-dd` (il valore di un campo data). */
const today = () => new Date().toLocaleDateString('sv-SE')

/** Duplica il mesociclo come nuova bozza dello stesso atleta e ci porta dentro. */
export function DuplicateMesocycle({
  mesocycle,
  open,
  onOpenChange,
}: {
  mesocycle: Target
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const run = useMutation({
    mutationFn: (v: { start_date: string; name: string }) => cloneMesocycle(mesocycle.id, v),
    onSuccess: async (id) => {
      onOpenChange(false)
      await queryClient.invalidateQueries({ queryKey: ['mesocycles', mesocycle.athlete_id] })
      await navigate({ to: '/mesocicli/$mesocycleId', params: { mesocycleId: id } })
    },
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    run.reset()
    const parsed = duplicateMesocycleSchema.safeParse(Object.fromEntries(new FormData(event.currentTarget)))
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    run.mutate(parsed.data)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form noValidate onSubmit={submit} className="grid gap-4">
          <DialogTitle>{copy.duplicateTitle(mesocycle.name)}</DialogTitle>
          <DialogDescription asChild>
            <ul className="grid list-disc gap-1.5 pl-5">
              {copy.duplicateBody.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </DialogDescription>
          <div className="grid gap-4 sm:grid-cols-[11rem_1fr]">
            <Field id="dup-start" label={copy.startDate} error={errors.start_date}>
              <Input
                id="dup-start"
                name="start_date"
                type="date"
                defaultValue={today()}
                className="h-9 text-sm"
              />
            </Field>
            <Field id="dup-name" label={copy.name} error={errors.name}>
              <Input
                id="dup-name"
                name="name"
                placeholder={copy.namePlaceholder(mesocycle.name)}
                maxLength={120}
                className="h-9 text-sm"
              />
            </Field>
          </div>
          {run.isError && (
            <p role="alert" className="text-sm text-destructive">
              {copy.errors.generic}
            </p>
          )}
          <div className="flex justify-end gap-2">
            <DialogCancel asChild>
              <Button type="button" variant="ghost">
                {m.cancel}
              </Button>
            </DialogCancel>
            <Button type="submit" disabled={run.isPending}>
              {run.isPending ? copy.working : copy.confirmDuplicate}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  )
}

/** Salva la programmazione di adesso come template del coach. */
export function SaveAsTemplate({
  mesocycle,
  coachId,
  open,
  onOpenChange,
}: {
  mesocycle: Target
  coachId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const queryClient = useQueryClient()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const [saved, setSaved] = useState<string | null>(null)
  const run = useMutation({
    mutationFn: (v: { name: string; description: string | null }) => saveAsTemplate(mesocycle.id, v),
    onSuccess: async (_, v) => {
      setSaved(v.name)
      await queryClient.invalidateQueries({ queryKey: ['templates', coachId] })
    },
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    run.reset()
    const parsed = saveTemplateSchema.safeParse(Object.fromEntries(new FormData(event.currentTarget)))
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    setErrors({})
    run.mutate(parsed.data)
  }
  function close(next: boolean) {
    if (!next) {
      setSaved(null)
      setErrors({})
      run.reset()
    }
    onOpenChange(next)
  }

  const duplicateName = run.isError && (run.error as { code?: string }).code === '23505'
  return (
    <Dialog open={open} onOpenChange={close}>
      <DialogContent>
        {saved ? (
          <div className="grid gap-4">
            <DialogTitle>{copy.templateSaved(saved)}</DialogTitle>
            <div className="flex justify-end">
              <DialogCancel asChild>
                <Button type="button">{copy.close}</Button>
              </DialogCancel>
            </div>
          </div>
        ) : (
          <form noValidate onSubmit={submit} className="grid gap-4">
            <DialogTitle>{copy.templateTitle(mesocycle.name)}</DialogTitle>
            <DialogDescription asChild>
              <ul className="grid list-disc gap-1.5 pl-5">
                {copy.templateBody.map((line) => (
                  <li key={line}>{line}</li>
                ))}
              </ul>
            </DialogDescription>
            <Field id="tpl-name" label={copy.templateName} error={errors.name}>
              <Input
                id="tpl-name"
                name="name"
                defaultValue={mesocycle.name}
                maxLength={120}
                className="h-9 text-sm"
              />
            </Field>
            <Field id="tpl-desc" label={copy.templateDescription} error={errors.description}>
              <textarea
                id="tpl-desc"
                name="description"
                rows={2}
                maxLength={500}
                className="w-full rounded-md border border-input bg-background px-2.5 py-1.5 text-sm dark:bg-input/30"
              />
            </Field>
            {run.isError && (
              <p role="alert" className="text-sm text-destructive">
                {duplicateName ? copy.errors.duplicateName : copy.errors.generic}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <DialogCancel asChild>
                <Button type="button" variant="ghost">
                  {m.cancel}
                </Button>
              </DialogCancel>
              <Button type="submit" disabled={run.isPending}>
                {run.isPending ? copy.working : copy.confirmTemplate}
              </Button>
            </div>
          </form>
        )}
      </DialogContent>
    </Dialog>
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
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  )
}
