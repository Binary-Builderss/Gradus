import type { ReactElement, ReactNode } from 'react'
import { Tooltip } from 'radix-ui'

/** Etichetta al passaggio del mouse o del focus; `disabled` lascia il figlio com'è. */
export function Tip({
  label,
  side = 'right',
  disabled = false,
  children,
}: {
  label: ReactNode
  side?: 'top' | 'right' | 'bottom' | 'left'
  disabled?: boolean
  children: ReactElement
}) {
  if (disabled) return children
  return (
    <Tooltip.Root>
      <Tooltip.Trigger asChild>{children}</Tooltip.Trigger>
      <Tooltip.Portal>
        <Tooltip.Content
          side={side}
          sideOffset={10}
          className="z-50 rounded-md border bg-popover px-2.5 py-1 text-xs font-medium text-popover-foreground shadow-md"
        >
          {label}
        </Tooltip.Content>
      </Tooltip.Portal>
    </Tooltip.Root>
  )
}

export const TooltipProvider = Tooltip.Provider
