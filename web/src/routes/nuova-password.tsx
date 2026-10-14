import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { AuthHeading, AuthLayout } from '@/components/auth/AuthLayout'
import { NewPasswordForm } from '@/components/auth/forms'
import { buttonVariants } from '@/components/ui/button'
import { mapAuthError } from '@/lib/auth'
import { messages } from '@/lib/messages'
import { supabase } from '@/lib/supabase'

const m = messages.auth.newPassword

// Il link dell'email apre questa pagina con la sessione di recupero, letta da supabase-js dall'URL.
export const Route = createFileRoute('/nuova-password')({
  loader: async () => {
    const { data } = await supabase.auth.getSession()
    return { hasSession: data.session !== null }
  },
  component: NewPasswordPage,
})

function NewPasswordPage() {
  const { hasSession } = Route.useLoaderData()
  const navigate = useNavigate()

  if (!hasSession) {
    return (
      <AuthLayout>
        <AuthHeading title={m.expiredTitle} subtitle={m.expired} />
        <Link to="/recupero-password" className={buttonVariants({ size: 'lg', className: 'h-11 w-full' })}>
          {m.requestNew}
        </Link>
      </AuthLayout>
    )
  }

  return (
    <AuthLayout>
      <AuthHeading title={m.title} subtitle={m.subtitle} />
      <NewPasswordForm
        onSubmit={async ({ password }) => {
          const { error } = await supabase.auth.updateUser({ password })
          if (error) return mapAuthError(error)
          await navigate({ to: '/' })
          return null
        }}
      />
    </AuthLayout>
  )
}
