import { CompassIcon, GearSixIcon, SignOutIcon } from '@phosphor-icons/react'
import { useQuery } from '@tanstack/react-query'
import type { CSSProperties } from 'react'
import { createFileRoute, Link, Outlet, redirect } from '@tanstack/react-router'
import { Wordmark } from '@/components/brand'
import { Sidebar } from '@/components/layout/Sidebar'
import { Button } from '@/components/ui/button'
import { TooltipProvider } from '@/components/ui/tooltip'
import { useGuidedTour } from '@/components/tour/useGuidedTour'
import { messages } from '@/lib/messages'
import { displayName, profileQuery } from '@/lib/profile'
import { useSidebarCollapsed } from '@/lib/useSidebarCollapsed'
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

function AppLayout() {
  const { user } = Route.useRouteContext()
  // L'uscita la gestisce il listener in main.tsx (SIGNED_OUT → /login).
  const signOut = () => void supabase.auth.signOut()
  const startTour = useGuidedTour(user.id)
  const profile = useQuery(profileQuery(user.id))
  const name = displayName(profile.data, user.email)
  const [collapsed, toggleSidebar] = useSidebarCollapsed()

  return (
    <TooltipProvider delayDuration={150}>
      <div
        className="min-h-dvh motion-reduce:transition-none lg:grid lg:grid-cols-[var(--sidebar-width)_1fr] lg:transition-[grid-template-columns] lg:duration-200"
        style={{ '--sidebar-width': collapsed ? '4.5rem' : '14.5rem' } as CSSProperties}
      >
        <Sidebar
          collapsed={collapsed}
          onToggle={toggleSidebar}
          name={name}
          email={user.email}
          onStartTour={() => void startTour()}
          onSignOut={signOut}
        />

        <header className="sticky top-0 z-10 flex items-center justify-between border-b bg-background/85 px-4 py-3 backdrop-blur lg:hidden">
          <Wordmark className="h-8" />
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
    </TooltipProvider>
  )
}
