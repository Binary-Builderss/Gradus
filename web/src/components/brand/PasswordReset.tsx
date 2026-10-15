import { useMutation } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { sendPasswordReset } from '@/lib/account'
import { messages } from '@/lib/messages'

const m = messages.app.account.security

export function PasswordReset({ email }: { email: string }) {
  const send = useMutation({ mutationFn: () => sendPasswordReset(email) })

  return (
    <section className="grid max-w-md gap-3" aria-labelledby="security-title">
      <h2 id="security-title" className="text-sm font-semibold">
        {m.title}
      </h2>
      <div className="grid gap-1">
        <p className="font-medium">{m.passwordTitle}</p>
        <p className="text-muted-foreground">{m.passwordBody}</p>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button variant="outline" disabled={send.isPending || send.isSuccess} onClick={() => send.mutate()}>
          {send.isPending ? m.passwordSending : m.passwordButton}
        </Button>
        {send.isSuccess && (
          <span role="status" className="text-sm text-muted-foreground">
            {m.passwordSent}
          </span>
        )}
        {send.isError && (
          <span role="alert" className="text-sm text-destructive">
            {m.passwordError}
          </span>
        )}
      </div>
    </section>
  )
}
