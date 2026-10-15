import type { ComponentProps } from 'react'
import { DropdownMenu } from 'radix-ui'
import { cn } from '@/lib/utils'

export const Menu = DropdownMenu.Root
export const MenuTrigger = DropdownMenu.Trigger

export function MenuContent({
  className,
  sideOffset = 8,
  ...props
}: ComponentProps<typeof DropdownMenu.Content>) {
  return (
    <DropdownMenu.Portal>
      <DropdownMenu.Content
        sideOffset={sideOffset}
        collisionPadding={8}
        className={cn(
          'z-50 min-w-60 rounded-lg border bg-popover p-1 text-popover-foreground shadow-lg outline-none',
          className,
        )}
        {...props}
      />
    </DropdownMenu.Portal>
  )
}

export function MenuItem({ className, ...props }: ComponentProps<typeof DropdownMenu.Item>) {
  return (
    <DropdownMenu.Item
      className={cn(
        'flex h-9 cursor-pointer items-center gap-2.5 rounded-md px-2.5 text-sm outline-none select-none data-[highlighted]:bg-accent data-[highlighted]:text-accent-foreground [&_svg]:size-[1.15rem] [&_svg]:text-muted-foreground data-[highlighted]:[&_svg]:text-accent-foreground',
        className,
      )}
      {...props}
    />
  )
}

export const MenuSeparator = ({ className, ...props }: ComponentProps<typeof DropdownMenu.Separator>) => (
  <DropdownMenu.Separator className={cn('-mx-1 my-1 h-px bg-border', className)} {...props} />
)
