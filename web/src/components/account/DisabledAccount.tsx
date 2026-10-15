import { useMutation, useQueryClient } from '@tanstack/react-query'
import { AuthHeading, AuthLayout } from '@/components/auth/AuthLayout'
import { Button } from '@/components/ui/button'
import { setAccountDisabled } from '@/lib/account'
import { messages } from '@/lib/messages'

const m = messages.app.account.disabled

/** Al posto dell'app quando l'account è disattivato: si può solo riattivarlo o uscire. */
export function DisabledAccount({ userId, onSignOut }: { userId: string; onSignOut: () => void }) {
  const queryClient = useQueryClient()
  const reactivate = useMutation({
    mutationFn: () => setAccountDisabled(userId, false),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['profile', userId] }),
  })

  return (
    <AuthLayout>
      <AuthHeading title={m.title} subtitle={m.body} />
      {reactivate.isError && (
        <p role="alert" className="mb-4 text-sm text-destructive">
          {m.error}
        </p>
      )}
      <div className="grid gap-2">
        <Button onClick={() => reactivate.mutate()} disabled={reactivate.isPending}>
          {reactivate.isPending ? m.reactivating : m.reactivate}
        </Button>
        <Button variant="ghost" onClick={onSignOut}>
          {messages.app.signOut}
        </Button>
      </div>
    </AuthLayout>
  )
}
