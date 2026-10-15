import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import {
  Dialog,
  DialogAction,
  DialogCancel,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { deleteAccount, setAccountDisabled } from '@/lib/account'
import { messages } from '@/lib/messages'
import { supabase } from '@/lib/supabase'

const m = messages.app.account.danger

/** Disattivare (reversibile) o eliminare (definitivo) l'account: due azioni distinte, la seconda con conferma scritta. */
export function DangerZone({ userId, email }: { userId: string; email: string }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [typed, setTyped] = useState('')
  const matches = typed.trim().toLowerCase() === email.trim().toLowerCase()

  const disable = useMutation({
    mutationFn: async () => {
      await setAccountDisabled(userId, true)
      await supabase.auth.signOut()
    },
  })
  const remove = useMutation({
    mutationFn: async () => {
      await deleteAccount(typed)
      await supabase.auth.signOut()
    },
    onSuccess: async () => {
      queryClient.clear()
      await navigate({ to: '/login' })
    },
  })

  return (
    <section className="grid max-w-md gap-4" aria-labelledby="danger-title">
      <h2 id="danger-title" className="text-sm font-semibold">
        {m.title}
      </h2>

      <div className="grid gap-2">
        <div>
          <p className="font-medium">{m.disableTitle}</p>
          <p className="text-muted-foreground">{m.disableBody}</p>
        </div>
        <Dialog>
          <DialogTrigger asChild>
            <Button variant="outline" className="w-fit">
              {m.disableButton}
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogTitle>{m.disableConfirmTitle}</DialogTitle>
            <DialogDescription>{m.disableConfirmBody}</DialogDescription>
            {disable.isError && (
              <p role="alert" className="text-sm text-destructive">
                {m.error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <DialogCancel asChild>
                <Button variant="ghost">{m.cancel}</Button>
              </DialogCancel>
              <DialogAction asChild>
                <Button
                  onClick={(e) => {
                    e.preventDefault()
                    disable.mutate()
                  }}
                  disabled={disable.isPending}
                >
                  {disable.isPending ? m.working : m.disableConfirm}
                </Button>
              </DialogAction>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      <div className="grid gap-2 border-t pt-4">
        <div>
          <p className="font-medium">{m.deleteTitle}</p>
          <p className="text-muted-foreground">{m.deleteBody}</p>
        </div>
        <Dialog onOpenChange={() => setTyped('')}>
          <DialogTrigger asChild>
            <Button variant="destructive" className="w-fit">
              {m.deleteButton}
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogTitle>{m.deleteConfirmTitle}</DialogTitle>
            <DialogDescription asChild>
              <ul className="grid list-disc gap-1.5 pl-5">
                {m.deleteConsequences.map((line) => (
                  <li key={line}>{line}</li>
                ))}
              </ul>
            </DialogDescription>
            <div className="grid gap-2">
              <label htmlFor="delete-confirm" className="text-sm">
                {m.deleteTypeEmail(email)}
              </label>
              <Input
                id="delete-confirm"
                value={typed}
                autoComplete="off"
                spellCheck={false}
                aria-label={m.deleteInputLabel}
                onChange={(e) => setTyped(e.target.value)}
              />
            </div>
            {remove.isError && (
              <p role="alert" className="text-sm text-destructive">
                {m.error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <DialogCancel asChild>
                <Button variant="ghost">{m.cancel}</Button>
              </DialogCancel>
              <DialogAction asChild>
                <Button
                  variant="destructive"
                  disabled={!matches || remove.isPending}
                  onClick={(e) => {
                    e.preventDefault()
                    remove.mutate()
                  }}
                >
                  {remove.isPending ? m.working : m.deleteConfirm}
                </Button>
              </DialogAction>
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </section>
  )
}
