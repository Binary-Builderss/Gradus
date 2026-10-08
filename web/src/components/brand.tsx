import { cn } from '@/lib/utils'
import { messages } from '@/lib/messages'

export function Wordmark({ className }: { className?: string }) {
  return (
    <span className={cn('font-display text-2xl font-bold tracking-wide uppercase', className)}>
      {messages.brand.name}
    </span>
  )
}

/** Gradini crescenti: la progressione settimana dopo settimana. L'ultimo è l'accento. */
export function Steps({ className }: { className?: string }) {
  const heights = [22, 34, 46, 58, 72, 100]
  return (
    <div aria-hidden className={cn('flex h-24 items-end gap-2', className)}>
      {heights.map((h, i) => (
        <span
          key={h}
          style={{ height: `${h}%` }}
          className={cn('w-5 rounded-sm', i === heights.length - 1 ? 'bg-primary' : 'bg-foreground/10')}
        />
      ))}
    </div>
  )
}
