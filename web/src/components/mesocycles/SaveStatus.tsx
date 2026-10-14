import { CheckCircleIcon, CircleNotchIcon, WarningCircleIcon } from '@phosphor-icons/react'
import { useIsMutating, useMutationState } from '@tanstack/react-query'
import { messages } from '@/lib/messages'

const m = messages.app.mesocycle.save

/** Stato del salvataggio automatico: tutte le mutazioni dell'editor hanno mutationKey ['editor']. */
export function SaveStatus() {
  const saving = useIsMutating({ mutationKey: ['editor'] }) > 0
  const latest = useMutationState({
    filters: { mutationKey: ['editor'] },
    select: (mutation) => ({ status: mutation.state.status, at: mutation.state.submittedAt }),
  }).reduce<{ status: string; at: number } | null>((a, b) => (a && a.at > b.at ? a : b), null)

  const failed = !saving && latest?.status === 'error'
  const Icon = saving ? CircleNotchIcon : failed ? WarningCircleIcon : CheckCircleIcon
  return (
    <p
      role="status"
      className={`flex items-center gap-2 text-sm ${failed ? 'text-destructive' : 'text-muted-foreground'}`}
    >
      <Icon size={18} className={saving ? 'animate-spin' : failed ? undefined : 'text-primary'} />
      {saving ? m.saving : failed ? m.error : m.saved}
    </p>
  )
}
