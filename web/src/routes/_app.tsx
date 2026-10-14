import { SignOutIcon, UsersThreeIcon } from '@phosphor-icons/react'
import { createFileRoute, Link, Outlet, redirect } from '@tanstack/react-router'
import { Wordmark } from '@/components/brand'
import { Button } from '@/components/ui/button'
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
  'flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-foreground data-[status=active]:bg-sidebar-accent data-[status=active]:text-foreground [&[data-status=active]_svg]:text-primary'

function AppLayout() {
  const { user } = Route.useRouteContext()
  // L'uscita la gestisce il listener in main.tsx (SIGNED_OUT → /login).
  const signOut = () => void supabase.auth.signOut()

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[15rem_1fr]">
      <aside className="sticky top-0 hidden h-dvh flex-col border-r bg-sidebar lg:flex">
        <Wordmark className="px-6 py-6" />
        <nav className="grid gap-1 px-3">
          <Link to="/" activeOptions={{ exact: true }} className={navLink}>
            <UsersThreeIcon size={20} weight="duotone" />
            {m.nav.athletes}
          </Link>
        </nav>
        <div className="mt-auto grid gap-1 border-t p-3">
          <p className="truncate px-3 py-1 text-sm text-muted-foreground" title={user.email}>
            {user.email}
          </p>
          <Button variant="ghost" className="justify-start gap-3 px-3" onClick={signOut}>
            <SignOutIcon size={20} />
            {m.signOut}
          </Button>
        </div>
      </aside>

      <header className="sticky top-0 z-10 flex items-center justify-between border-b bg-background/85 px-4 py-3 backdrop-blur lg:hidden">
        <Wordmark className="text-xl" />
        <Button variant="ghost" size="icon" aria-label={m.signOut} onClick={signOut}>
          <SignOutIcon size={20} />
        </Button>
      </header>

      <main className="mx-auto w-full max-w-6xl px-4 py-8 sm:px-8 lg:py-12">
        <Outlet />
      </main>
    </div>
  )
}
