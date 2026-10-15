import { PaperPlaneTiltIcon, UserPlusIcon, XIcon } from '@phosphor-icons/react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { emailSchema } from '@/lib/auth'
import { inviteResultMessage } from '@/lib/inviteMessages'
import { inviteAthlete } from '@/lib/invites'
import { messages } from '@/lib/messages'

const m = messages.app.athletes.invite

export function InviteAthlete() {
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [fieldError, setFieldError] = useState<string | null>(null)
  const [done, setDone] = useState<string | null>(null)

  const invite = useMutation({
    mutationFn: inviteAthlete,
    onSuccess: async (result) => {
      setDone(inviteResultMessage(result))
      await queryClient.invalidateQueries({ queryKey: ['athletes'] })
    },
  })

  function close() {
    setOpen(false)
    setFieldError(null)
    setDone(null)
    invite.reset()
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = event.currentTarget
    const parsed = emailSchema.safeParse(Object.fromEntries(new FormData(form)))
    if (!parsed.success) {
      setFieldError(parsed.error.issues[0]?.message ?? null)
      return
    }
    setFieldError(null)
    setDone(null)
    invite.mutate(parsed.data.email, { onSuccess: () => form.reset() })
  }

  if (!open) {
    return (
      <Button onClick={() => setOpen(true)} data-tour="invite">
        <UserPlusIcon data-icon="inline-start" />
        {m.open}
      </Button>
    )
  }

  const error = fieldError ?? (invite.isError ? invite.error.message : null)
  return (
    <form
      noValidate
      onSubmit={submit}
      className="grid w-full gap-3 rounded-lg border bg-card p-4 sm:max-w-md"
    >
      <div className="flex items-center justify-between">
        <Label htmlFor="invite-email">{m.label}</Label>
        <Button type="button" variant="ghost" size="icon-sm" aria-label={m.close} onClick={close}>
          <XIcon />
        </Button>
      </div>
      <Input
        id="invite-email"
        name="email"
        type="email"
        autoComplete="off"
        autoFocus
        aria-invalid={error ? true : undefined}
        aria-describedby="invite-feedback"
        className="h-9 text-sm"
      />
      <p id="invite-feedback" role={error ? 'alert' : 'status'} className="min-h-5 text-sm">
        {error ? (
          <span className="text-destructive">{error}</span>
        ) : (
          <span className="text-primary">{done}</span>
        )}
      </p>
      <Button type="submit" disabled={invite.isPending}>
        {invite.isPending ? m.sending : m.send}
        {!invite.isPending && <PaperPlaneTiltIcon data-icon="inline-end" />}
      </Button>
    </form>
  )
}
