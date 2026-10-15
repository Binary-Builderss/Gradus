import { cn } from '@/lib/utils'
import { messages } from '@/lib/messages'

/** Tre gradini crescenti: la progressione settimana dopo settimana. L'ultimo è l'accento. */
export function Mark({ className }: { className?: string }) {
  return (
    <span aria-hidden className={cn('flex h-4 items-end gap-0.5', className)}>
      <span className="h-1.5 w-1 rounded-[1px] bg-foreground/25" />
      <span className="h-2.5 w-1 rounded-[1px] bg-foreground/25" />
      <span className="h-4 w-1 rounded-[1px] bg-primary" />
    </span>
  )
}

export function Wordmark({ className }: { className?: string }) {
  return (
    <span className={cn('flex items-center gap-2 text-base font-semibold tracking-tight', className)}>
      <Mark />
      {messages.brand.name}
    </span>
  )
}
