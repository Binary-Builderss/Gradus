import { PaperPlaneTiltIcon, UserPlusIcon, XIcon } from '@phosphor-icons/react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { emailSchema } from '@/lib/auth'
import { inviteResultMessage } from '@/lib/inviteMessages'
import { followSelf } from '@/lib/athletes'
import { inviteAthlete } from '@/lib/invites'
import { messages } from '@/lib/messages'

const m = messages.app.athletes.invite

/** `limit`: tetto di atleti già raggiunto (null = si può invitare). */
export function InviteAthlete({
  limit,
  userId,
  userEmail,
  seats,
}: {
  limit: number | null
  userId: string
  /** L'email di chi invita: se la scrive, vuole seguirsi da solo, non invitarsi. */
  userEmail: string | undefined
  /** Posti usati e tetto del piano, per dire quanti ne restano (`near`: sono quasi finiti). */
  seats?: { used: number; limit: number | null; near: boolean }
}) {
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [fieldError, setFieldError] = useState<string | null>(null)
  const [done, setDone] = useState<string | null>(null)

  const invite = useMutation({
    mutationFn: async (args: { email: string; name?: string }) => {
      if (userEmail && args.email.trim().toLowerCase() === userEmail.trim().toLowerCase()) {
        await followSelf(userId)
        return 'self' as const
      }
      return inviteAthlete(args)
    },
    onSuccess: async (result) => {
      setDone(result === 'self' ? messages.app.athletes.followSelfDone : inviteResultMessage(result))
      await queryClient.invalidateQueries({ queryKey: ['athletes'] })
      await queryClient.invalidateQueries({ queryKey: ['plan-usage'] })
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
    const name = String(new FormData(form).get('name') ?? '').trim()
    invite.mutate({ email: parsed.data.email, name: name || undefined }, { onSuccess: () => form.reset() })
  }

  if (limit !== null) {
    return (
      <div className="grid max-w-xs gap-1.5 sm:justify-items-end" data-tour="invite">
        <Button disabled>
          <UserPlusIcon data-icon="inline-start" />
          {m.open}
        </Button>
        <p className="text-sm text-muted-foreground sm:text-right">
          {m.limitFull(limit)}{' '}
          <Link to="/piani" className="text-primary underline-offset-4 hover:underline">
            {m.limitUpgrade}
          </Link>
        </p>
      </div>
    )
  }

  if (!open) {
    return (
      <div className="grid gap-1.5 sm:justify-items-end">
        <Button onClick={() => setOpen(true)} data-tour="invite">
          <UserPlusIcon data-icon="inline-start" />
          {m.open}
        </Button>
        {seats && (
          <p className="text-xs text-muted-foreground">
            {messages.app.athletes.seats(seats.used, seats.limit)}
            {seats.near && (
              <>
                {' · '}
                <Link to="/piani" className="text-primary underline-offset-4 hover:underline">
                  {messages.app.athletes.seatsMore}
                </Link>
              </>
            )}
          </p>
        )}
      </div>
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
      <div className="grid gap-2">
        <Label htmlFor="invite-name">{m.nameLabel}</Label>
        <Input id="invite-name" name="name" autoComplete="off" maxLength={80} className="h-9 text-sm" />
        <p className="text-xs text-muted-foreground">{m.nameHint}</p>
      </div>
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
