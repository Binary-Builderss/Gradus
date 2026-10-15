import { PencilSimpleIcon, StackIcon, TrashIcon } from '@phosphor-icons/react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
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
import { messages } from '@/lib/messages'
import { deleteTemplate, renameTemplate, type Template, templatesQuery } from '@/lib/templates'

const m = messages.app.templates

const dateFormat = new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short', year: 'numeric' })

/** Elenco dei template del coach, con rinomina ed eliminazione. */
export function TemplateList({ coachId }: { coachId: string }) {
  const queryClient = useQueryClient()
  const templates = useQuery(templatesQuery(coachId))
  const [renaming, setRenaming] = useState<string | null>(null)
  const [removing, setRemoving] = useState<Template | null>(null)
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['templates', coachId] })

  const remove = useMutation({
    mutationFn: (id: string) => deleteTemplate(coachId, id),
    onSuccess: async () => {
      setRemoving(null)
      await refresh()
    },
  })

  return (
    <section className="space-y-5">
      <div className="grid gap-1">
        <h1 className="text-xl font-semibold tracking-tight">{m.title}</h1>
        <p className="max-w-prose text-sm text-muted-foreground">{m.intro}</p>
      </div>

      {templates.isPending ? (
        <div aria-hidden className="h-24 animate-pulse rounded-lg border bg-muted/40" />
      ) : templates.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : templates.data.length === 0 ? (
        <div className="space-y-1 rounded-lg border border-dashed p-5" data-tour="template-list">
          <p className="font-medium">{m.empty}</p>
          <p className="max-w-prose text-sm text-muted-foreground">{m.howToSave}</p>
        </div>
      ) : (
        <ul className="divide-y overflow-hidden rounded-lg border bg-card" data-tour="template-list">
          {templates.data.map((t) => (
            <li key={t.id} className="grid gap-1 px-4 py-3">
              {renaming === t.id ? (
                <RenameForm
                  template={t}
                  coachId={coachId}
                  onDone={async () => {
                    setRenaming(null)
                    await refresh()
                  }}
                  onCancel={() => setRenaming(null)}
                />
              ) : (
                <div className="flex flex-wrap items-center gap-3">
                  <StackIcon size={18} className="shrink-0 text-muted-foreground" />
                  <p className="min-w-0 flex-1 truncate font-medium">{t.name}</p>
                  <span className="text-xs text-muted-foreground">
                    {m.weeks(t.weeks)} · {m.sessions(t.sessions)}
                  </span>
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label={`${m.rename}: ${t.name}`}
                    title={m.rename}
                    onClick={() => setRenaming(t.id)}
                  >
                    <PencilSimpleIcon />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label={`${m.remove}: ${t.name}`}
                    title={m.remove}
                    onClick={() => {
                      remove.reset()
                      setRemoving(t)
                    }}
                  >
                    <TrashIcon />
                  </Button>
                </div>
              )}
              {t.description && <p className="pl-[30px] text-sm text-muted-foreground">{t.description}</p>}
              <p className="pl-[30px] text-xs text-muted-foreground">
                {m.created(dateFormat.format(new Date(t.created_at)))}
              </p>
            </li>
          ))}
        </ul>
      )}

      <Dialog open={removing !== null} onOpenChange={(next) => !next && setRemoving(null)}>
        {removing && (
          <DialogContent>
            <DialogTitle>{m.removeTitle(removing.name)}</DialogTitle>
            <DialogDescription asChild>
              <ul className="grid list-disc gap-1.5 pl-5">
                {m.removeBody.map((line) => (
                  <li key={line}>{line}</li>
                ))}
              </ul>
            </DialogDescription>
            {remove.isError && (
              <p role="alert" className="text-sm text-destructive">
                {m.errors.generic}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <DialogCancel asChild>
                <Button variant="ghost">{m.cancel}</Button>
              </DialogCancel>
              <Button
                variant="destructive"
                disabled={remove.isPending}
                onClick={() => remove.mutate(removing.id)}
              >
                {remove.isPending ? m.working : m.removeConfirm}
              </Button>
            </div>
          </DialogContent>
        )}
      </Dialog>
    </section>
  )
}

function RenameForm({
  template,
  coachId,
  onDone,
  onCancel,
}: {
  template: Template
  coachId: string
  onDone: () => void
  onCancel: () => void
}) {
  const [error, setError] = useState<string | null>(null)
  const rename = useMutation({
    mutationFn: (name: string) => renameTemplate(coachId, template.id, name),
    onSuccess: onDone,
    onError: (e: { code?: string }) =>
      setError(e.code === '23505' ? m.errors.duplicateName : m.errors.generic),
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const name = String(new FormData(event.currentTarget).get('name') ?? '').trim()
    if (!name) return setError(m.errors.nameRequired)
    if (name.length > 120) return setError(m.errors.nameTooLong)
    setError(null)
    if (name === template.name) return onCancel()
    rename.mutate(name)
  }

  return (
    <form noValidate onSubmit={submit} className="grid gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <Input
          name="name"
          aria-label={m.renameLabel}
          defaultValue={template.name}
          maxLength={120}
          autoFocus
          aria-invalid={error ? true : undefined}
          className="h-9 max-w-sm flex-1 text-sm"
        />
        <Button type="submit" disabled={rename.isPending}>
          {rename.isPending ? m.working : m.save}
        </Button>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {m.cancel}
        </Button>
      </div>
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </form>
  )
}
