import { Link } from '@tanstack/react-router'
import { AuthHeading, AuthLayout } from '@/components/auth/AuthLayout'
import { buttonVariants } from '@/components/ui/button'
import { messages } from '@/lib/messages'
import { usePageTitle } from '@/lib/pageTitle'
import { cn } from '@/lib/utils'

const m = messages.auth.notFound

/** Indirizzo sbagliato (per esempio /accedi): invece di un «Not Found» nudo, la strada per l'accesso. */
export function NotFound() {
  usePageTitle(m.title)
  return (
    <AuthLayout>
      <AuthHeading title={m.title} subtitle={m.subtitle} />
      {/* /login porta all'app se l'utente è già dentro. */}
      <Link to="/login" className={cn(buttonVariants(), 'w-full')}>
        {m.toLogin}
      </Link>
    </AuthLayout>
  )
}
