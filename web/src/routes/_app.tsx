import { BarbellIcon, CompassIcon, GearSixIcon, SignOutIcon, UsersThreeIcon } from '@phosphor-icons/react'
import { createFileRoute, Link, Outlet, redirect } from '@tanstack/react-router'
import { Wordmark } from '@/components/brand'
import { Button } from '@/components/ui/button'
import { useGuidedTour } from '@/components/tour/useGuidedTour'
import { messages } from '@/lib/messages'
import { supabase } from '@/lib/supabase'

const m = messages.app

// Area riservata: senza sessione si torna al login.
export const Route = createFileRoute('/_app')({
  beforeLoad: async () => {
    const { data } = await supabase.auth.getSession()
    if (!data.session) throw redirect({ to: '/login' })
    return { user: data.session.user }
  },
  component: AppLayout,
})

// TanStack Router marca il link attivo con data-status="active".
const navLink =
  'flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-foreground data-[status=active]:bg-accent data-[status=active]:text-accent-foreground [&[data-status=active]_svg]:text-primary'

function AppLayout() {
  const { user } = Route.useRouteContext()
  // L'uscita la gestisce il listener in main.tsx (SIGNED_OUT → /login).
  const signOut = () => void supabase.auth.signOut()
  const startTour = useGuidedTour(user.id)

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[13.5rem_1fr]">
      <aside className="sticky top-0 hidden h-dvh flex-col border-r bg-sidebar lg:flex">
        <Wordmark className="px-5 py-4" />
        <nav className="grid gap-0.5 px-2.5">
          <Link to="/" activeOptions={{ exact: true }} className={navLink} data-tour="nav-athletes">
            <UsersThreeIcon size={18} />
            {m.nav.athletes}
          </Link>
          <Link to="/esercizi" className={navLink}>
            <BarbellIcon size={18} />
            {m.nav.exercises}
          </Link>
          <Link to="/impostazioni" className={navLink} data-tour="nav-settings">
            <GearSixIcon size={18} />
            {m.nav.settings}
          </Link>
        </nav>
        <div className="mt-auto grid gap-0.5 border-t p-2.5">
          <p className="truncate px-2.5 py-1 text-xs text-muted-foreground" title={user.email}>
            {user.email}
          </p>
          <Button
            variant="ghost"
            className="justify-start gap-2.5 px-2.5 text-muted-foreground"
            onClick={() => void startTour()}
          >
            <CompassIcon size={18} />
            {m.tour.open}
          </Button>
          <Button
            variant="ghost"
            className="justify-start gap-2.5 px-2.5 text-muted-foreground"
            onClick={signOut}
          >
            <SignOutIcon size={18} />
            {m.signOut}
          </Button>
        </div>
      </aside>

      <header className="sticky top-0 z-10 flex items-center justify-between border-b bg-background/85 px-4 py-3 backdrop-blur lg:hidden">
        <Wordmark />
        <div className="flex items-center">
          <Button variant="ghost" size="icon" aria-label={m.nav.settings} asChild>
            <Link to="/impostazioni">
              <GearSixIcon size={18} />
            </Link>
          </Button>
          <Button variant="ghost" size="icon" aria-label={m.tour.open} onClick={() => void startTour()}>
            <CompassIcon size={18} />
          </Button>
          <Button variant="ghost" size="icon" aria-label={m.signOut} onClick={signOut}>
            <SignOutIcon size={18} />
          </Button>
        </div>
      </header>

      <main className="w-full min-w-0 px-4 py-6 sm:px-8 lg:py-8">
        <Outlet />
      </main>
    </div>
  )
}
