import {
  BarbellIcon,
  CaretLeftIcon,
  CaretRightIcon,
  CompassIcon,
  GearSixIcon,
  SignOutIcon,
  UsersThreeIcon,
  type Icon,
} from '@phosphor-icons/react'
import { Link } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { Mark, Wordmark } from '@/components/brand'
import { Button } from '@/components/ui/button'
import { Tip } from '@/components/ui/tooltip'
import { initials } from '@/lib/athleteStats'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app

const item =
  'group/item flex h-9 items-center gap-3 rounded-md px-2.5 text-sm font-medium text-muted-foreground transition-colors outline-none hover:bg-sidebar-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring'
// TanStack Router marca il link attivo con data-status="active".
const itemActive =
  'data-[status=active]:bg-accent data-[status=active]:text-accent-foreground [&[data-status=active]_svg]:text-primary'

function NavItem({
  to,
  exact,
  icon: IconComponent,
  label,
  collapsed,
  tour,
}: {
  to: '/' | '/esercizi' | '/impostazioni'
  exact?: boolean
  icon: Icon
  label: string
  collapsed: boolean
  tour?: string
}) {
  return (
    <Tip label={label} disabled={!collapsed}>
      <Link
        to={to}
        activeOptions={{ exact }}
        data-tour={tour}
        className={cn(item, itemActive, collapsed && 'justify-center px-0')}
      >
        {({ isActive }) => (
          <>
            <IconComponent size={20} weight={isActive ? 'fill' : 'regular'} />
            <span className={cn(collapsed && 'sr-only')}>{label}</span>
          </>
        )}
      </Link>
    </Tip>
  )
}

function ActionItem({
  icon: IconComponent,
  label,
  collapsed,
  onClick,
}: {
  icon: Icon
  label: string
  collapsed: boolean
  onClick: () => void
}) {
  return (
    <Tip label={label} disabled={!collapsed}>
      <button
        type="button"
        onClick={onClick}
        className={cn(item, 'w-full', collapsed && 'justify-center px-0')}
      >
        <IconComponent size={20} />
        <span className={cn(collapsed && 'sr-only')}>{label}</span>
      </button>
    </Tip>
  )
}

/** Menu laterale: in alto il marchio, al centro le sezioni di lavoro, in basso guida, impostazioni e utente. */
export function Sidebar({
  collapsed,
  onToggle,
  name,
  email,
  onStartTour,
  onSignOut,
}: {
  collapsed: boolean
  onToggle: () => void
  name: string
  email: string | undefined
  onStartTour: () => void
  onSignOut: () => void
}): ReactNode {
  const toggle = (
    <Tip label={collapsed ? m.nav.expand : m.nav.collapse} disabled={!collapsed}>
      <Button
        variant="ghost"
        size="icon"
        aria-label={collapsed ? m.nav.expand : m.nav.collapse}
        aria-expanded={!collapsed}
        aria-controls="sidebar-nav"
        onClick={onToggle}
        className="text-muted-foreground"
      >
        {collapsed ? <CaretRightIcon /> : <CaretLeftIcon />}
      </Button>
    </Tip>
  )

  return (
    <aside className="sticky top-0 hidden h-dvh flex-col overflow-hidden border-r bg-sidebar lg:flex">
      {collapsed ? (
        <div className="grid justify-items-center gap-2 pt-4 pb-2">
          <Mark className="h-7" />
          {toggle}
        </div>
      ) : (
        <div className="flex items-center justify-between py-3 pr-2 pl-4">
          <Wordmark className="h-8" />
          {toggle}
        </div>
      )}

      <nav id="sidebar-nav" aria-label={m.nav.menu} className="mt-1 grid gap-0.5 px-2">
        <NavItem
          to="/"
          exact
          icon={UsersThreeIcon}
          label={m.nav.athletes}
          collapsed={collapsed}
          tour="nav-athletes"
        />
        <NavItem to="/esercizi" icon={BarbellIcon} label={m.nav.exercises} collapsed={collapsed} />
      </nav>

      <div className="mt-auto grid gap-0.5 border-t px-2 py-2">
        <ActionItem icon={CompassIcon} label={m.tour.open} collapsed={collapsed} onClick={onStartTour} />
        <NavItem
          to="/impostazioni"
          icon={GearSixIcon}
          label={m.nav.settings}
          collapsed={collapsed}
          tour="nav-settings"
        />
        <div
          className={cn(
            'mt-1 flex items-center gap-2.5 border-t pt-3',
            collapsed ? 'flex-col px-0' : 'px-1.5',
          )}
        >
          <Tip label={name} disabled={!collapsed}>
            <span
              aria-hidden
              className="grid size-8 shrink-0 place-items-center rounded-full bg-accent text-xs font-semibold text-accent-foreground"
            >
              {initials(name)}
            </span>
          </Tip>
          {collapsed ? (
            <span className="sr-only">{name}</span>
          ) : (
            <div className="min-w-0 flex-1" title={email}>
              <p className="truncate text-sm font-medium">{name}</p>
              {email && email !== name && <p className="truncate text-xs text-muted-foreground">{email}</p>}
            </div>
          )}
          <Tip label={m.signOut} disabled={!collapsed}>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={m.signOut}
              className="text-muted-foreground"
              onClick={onSignOut}
            >
              <SignOutIcon />
            </Button>
          </Tip>
        </div>
      </div>
    </aside>
  )
}
