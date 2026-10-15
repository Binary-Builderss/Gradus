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
import { deleteDraftMesocycle, type MesocycleStatus as Status, setMesocycleStatus } from '@/lib/mesocycles'
import { statusErrorMessage } from '@/lib/mesocycleStatus'
import { messages } from '@/lib/messages'

const m = messages.app.mesocycle.status
const label = messages.app.athleteDetail.status

type Action = 'activate' | 'complete' | 'unpublish' | 'remove'

/**
 * Stato del mesociclo e il modo di cambiarlo: bozza → attivo → concluso. Le regole le decide il database
 * (mesociclo vuoto, un solo attivo per atleta, sedute registrate): qui si mostra l'esito.
 */
export function MesocycleStatus({
  mesocycle,
}: {
  mesocycle: { id: string; name: string; status: Status; athlete_id: string }
}) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [pending, setPending] = useState<Action | null>(null)

  const run = useMutation({
    mutationFn: async (action: Action) => {
      if (action === 'remove') return deleteDraftMesocycle(mesocycle.id)
      const to: Status = action === 'activate' ? 'active' : action === 'complete' ? 'completed' : 'draft'
      return setMesocycleStatus(mesocycle.id, to)
    },
    onSuccess: async (_, action) => {
      setPending(null)
      await queryClient.invalidateQueries({ queryKey: ['mesocycle', mesocycle.id] })
      await queryClient.invalidateQueries({ queryKey: ['mesocycles', mesocycle.athlete_id] })
      if (action === 'remove')
        await navigate({ to: '/atleti/$athleteId', params: { athleteId: mesocycle.athlete_id } })
    },
  })

  const { status, name } = mesocycle
  const copy = {
    activate: { title: m.activateTitle(name), body: m.activateBody, confirm: m.activate },
    complete: { title: m.completeTitle(name), body: m.completeBody, confirm: m.complete },
    unpublish: {
      title: m.unpublishTitle(name),
      body: m.unpublishBody,
      confirm: m.unpublish.replace('…', ''),
    },
    remove: { title: m.removeTitle(name), body: m.removeBody, confirm: m.remove.replace('…', '') },
  } as const
  const open = (action: Action) => {
    run.reset()
    setPending(action)
  }

  return (
    <div className="flex items-center gap-2" data-tour="meso-status">
      <span className="rounded-full bg-accent px-2 py-0.5 text-xs font-medium text-accent-foreground">
        {label[status]}
      </span>
      {status === 'draft' && <Button onClick={() => open('activate')}>{m.activate}</Button>}
      {status === 'active' && (
        <Button variant="outline" onClick={() => open('complete')}>
          {m.complete}
        </Button>
      )}
      {status !== 'completed' && (
        <Menu>
          <MenuTrigger asChild>
            <Button variant="ghost" size="icon" aria-label={m.more}>
              <DotsThreeIcon weight="bold" />
            </Button>
          </MenuTrigger>
          <MenuContent align="end" className="min-w-52">
            {status === 'active' ? (
              <MenuItem onSelect={() => open('unpublish')}>{m.unpublish}</MenuItem>
            ) : (
              <MenuItem onSelect={() => open('remove')}>{m.remove}</MenuItem>
            )}
          </MenuContent>
        </Menu>
      )}

      <Dialog open={pending !== null} onOpenChange={(next) => !next && setPending(null)}>
        {pending && (
          <DialogContent>
            <DialogTitle>{copy[pending].title}</DialogTitle>
            <DialogDescription asChild>
              <ul className="grid list-disc gap-1.5 pl-5">
                {copy[pending].body.map((line) => (
                  <li key={line}>{line}</li>
                ))}
              </ul>
            </DialogDescription>
            {run.isError && (
              <p role="alert" className="text-sm text-destructive">
                {statusErrorMessage(run.error as { message?: string; hint?: string | null })}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <DialogCancel asChild>
                <Button variant="ghost">{m.cancel}</Button>
              </DialogCancel>
              <DialogAction asChild>
                <Button
                  variant={pending === 'remove' ? 'destructive' : 'default'}
                  disabled={run.isPending}
                  onClick={(e) => {
                    e.preventDefault()
                    run.mutate(pending)
                  }}
                >
                  {run.isPending ? m.working : copy[pending].confirm}
                </Button>
              </DialogAction>
            </div>
          </DialogContent>
        )}
      </Dialog>
    </div>
  )
}
