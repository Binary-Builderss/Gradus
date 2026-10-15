import {
  CaretUpDownIcon,
  CompassIcon,
  CrownSimpleIcon,
  PaintBrushIcon,
  SignOutIcon,
  UserIcon,
} from '@phosphor-icons/react'
import { Link } from '@tanstack/react-router'
import { Menu, MenuContent, MenuItem, MenuSeparator, MenuTrigger } from '@/components/ui/dropdown-menu'
import { Tip } from '@/components/ui/tooltip'
import { initials } from '@/lib/athleteStats'
import { messages } from '@/lib/messages'
import type { PlanUsage } from '@/lib/plans'
import { cn } from '@/lib/utils'

const m = messages.app

/**
 * Il menu della persona collegata: profilo, personalizza, piano ed esci stanno qui, come nelle app di lavoro che
 * conosci. Nel menu laterale è una riga con nome ed email, da compresso solo l'avatar; nell'header mobile
 * solo l'avatar (e lì dentro c'è anche la guida, che non ha un pulsante suo).
 */
export function AccountMenu({
  name,
  email,
  usage,
  variant,
  collapsed = false,
  onStartTour,
  onSignOut,
}: {
  name: string
  email: string | undefined
  /** Piano e posti; undefined finché non si sa. */
  usage: PlanUsage | undefined
  variant: 'sidebar' | 'header'
  collapsed?: boolean
  onStartTour?: () => void
  onSignOut: () => void
}) {
  const avatarOnly = variant === 'header' || collapsed
  const avatar = (
    <span
      aria-hidden
      className="grid size-8 shrink-0 place-items-center rounded-full bg-accent text-xs font-semibold text-accent-foreground"
    >
      {initials(name)}
    </span>
  )

  return (
    <Menu>
      <Tip label={name} disabled={!collapsed || variant === 'header'}>
        <MenuTrigger asChild>
          <button
            type="button"
            aria-label={avatarOnly ? `${m.nav.account}: ${name}` : undefined}
            data-tour="account-menu"
            className={cn(
              'flex min-w-0 items-center gap-2.5 rounded-md text-left transition-colors outline-none hover:bg-sidebar-accent focus-visible:ring-2 focus-visible:ring-ring data-[state=open]:bg-sidebar-accent',
              avatarOnly ? 'justify-center p-1' : 'w-full px-1.5 py-1.5',
            )}
          >
            {avatar}
            {!avatarOnly && (
              <>
                <span className="grid min-w-0 flex-1">
                  <span className="truncate text-sm font-medium">{name}</span>
                  {email && email !== name && (
                    <span className="truncate text-xs text-muted-foreground">{email}</span>
                  )}
                </span>
                <CaretUpDownIcon size={16} className="shrink-0 text-muted-foreground" />
              </>
            )}
          </button>
        </MenuTrigger>
      </Tip>
      <MenuContent
        side={variant === 'header' ? 'bottom' : collapsed ? 'right' : 'top'}
        align={variant === 'header' ? 'end' : 'start'}
      >
        <div className="grid gap-0.5 px-2.5 py-2">
          <p className="truncate text-sm font-medium">{name}</p>
          {email && email !== name && <p className="truncate text-xs text-muted-foreground">{email}</p>}
          {usage && (
            <p className="mt-1 w-fit rounded border px-1.5 py-px text-xs text-muted-foreground">
              {m.plans.planName[usage.plan]}
            </p>
          )}
        </div>
        <MenuSeparator />
        <MenuItem asChild>
          <Link to="/profilo">
            <UserIcon />
            {m.nav.profile}
          </Link>
        </MenuItem>
        <MenuItem asChild>
          <Link to="/personalizza">
            <PaintBrushIcon />
            {m.nav.customize}
            {usage && !usage.canCustomize && (
              <span className="ml-auto rounded border px-1.5 py-px text-xs text-muted-foreground">Pro</span>
            )}
          </Link>
        </MenuItem>
        <MenuItem asChild>
          <Link to="/piani">
            <CrownSimpleIcon />
            {m.nav.plans}
          </Link>
        </MenuItem>
        {variant === 'header' && onStartTour && (
          <MenuItem onSelect={onStartTour}>
            <CompassIcon />
            {m.tour.open}
          </MenuItem>
        )}
        <MenuSeparator />
        <MenuItem onSelect={onSignOut}>
          <SignOutIcon />
          {m.signOut}
        </MenuItem>
      </MenuContent>
    </Menu>
  )
}
