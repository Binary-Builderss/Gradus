import { DotsThreeIcon } from '@phosphor-icons/react'
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
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/components/ui/dropdown-menu'
import { endLink } from '@/lib/athletes'
import { messages } from '@/lib/messages'

const m = messages.app.athletes.closeLink

/** Chiusura del collegamento con un atleta, con conferma che dice cosa cambia. */
export function CloseLink({
  coachId,
  athleteId,
  name,
}: {
  coachId: string
  athleteId: string
  name: string
}) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)
  const close = useMutation({
    mutationFn: () => endLink(coachId, athleteId),
    onSuccess: async () => {
      setOpen(false)
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['athletes'] }),
        queryClient.invalidateQueries({ queryKey: ['plan-usage'] }),
      ])
      await navigate({ to: '/' })
    },
  })

  return (
    <>
      <Menu>
        <MenuTrigger asChild>
          <Button variant="ghost" size="icon" aria-label={m.more}>
            <DotsThreeIcon weight="bold" />
          </Button>
        </MenuTrigger>
        <MenuContent align="end" className="min-w-52">
          <MenuItem
            onSelect={() => {
              close.reset()
              setOpen(true)
            }}
          >
            {m.menu}
          </MenuItem>
        </MenuContent>
      </Menu>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogTitle>{m.title(name)}</DialogTitle>
          <DialogDescription asChild>
            <ul className="grid list-disc gap-1.5 pl-5">
              {m.body.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </DialogDescription>
          {close.isError && (
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
                disabled={close.isPending}
                onClick={(e) => {
                  e.preventDefault()
                  close.mutate()
                }}
              >
                {close.isPending ? m.working : m.confirm}
              </Button>
            </DialogAction>
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}
