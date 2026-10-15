import type { ComponentProps } from 'react'
import { AlertDialog } from 'radix-ui'
import { cn } from '@/lib/utils'

export const Dialog = AlertDialog.Root
export const DialogTrigger = AlertDialog.Trigger
export const DialogCancel = AlertDialog.Cancel
export const DialogAction = AlertDialog.Action

export function DialogContent({ className, children, ...props }: ComponentProps<typeof AlertDialog.Content>) {
  return (
    <AlertDialog.Portal>
      <AlertDialog.Overlay className="fixed inset-0 z-50 bg-foreground/40" />
      <AlertDialog.Content
        className={cn(
          'fixed top-1/2 left-1/2 z-50 grid w-[calc(100%-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 gap-4 rounded-lg border bg-popover p-6 text-popover-foreground shadow-lg outline-none',
          className,
        )}
        {...props}
      >
        {children}
      </AlertDialog.Content>
    </AlertDialog.Portal>
  )
}

export const DialogTitle = ({ className, ...props }: ComponentProps<typeof AlertDialog.Title>) => (
  <AlertDialog.Title className={cn('text-base font-semibold', className)} {...props} />
)

export const DialogDescription = ({
  className,
  ...props
}: ComponentProps<typeof AlertDialog.Description>) => (
  <AlertDialog.Description className={cn('text-muted-foreground', className)} {...props} />
)
