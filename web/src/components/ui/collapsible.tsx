import { CaretRightIcon } from '@phosphor-icons/react'
import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

/** Sezione richiudibile nativa (`<details>`): chiusa di default, mostra solo il titolo. */
export function Collapsible({
  title,
  className,
  children,
  ...props
}: {
  title: ReactNode
  className?: string
  children: ReactNode
} & Omit<React.ComponentProps<'details'>, 'title' | 'children' | 'className'>) {
  return (
    <details className={cn('group', className)} {...props}>
      <summary className="flex w-fit cursor-pointer list-none items-center gap-2 rounded-md text-sm font-medium select-none focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none [&::-webkit-details-marker]:hidden">
        <CaretRightIcon size={14} className="transition-transform group-open:rotate-90" />
        {title}
      </summary>
      <div className="mt-3 grid gap-3">{children}</div>
    </details>
  )
}
