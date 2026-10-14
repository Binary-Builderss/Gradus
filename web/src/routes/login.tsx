import { createFileRoute, Link, redirect, useNavigate } from '@tanstack/react-router'
import { AuthHeading, AuthLayout } from '@/components/auth/AuthLayout'
import { LoginForm } from '@/components/auth/forms'
import { mapAuthError } from '@/lib/auth'
import { messages } from '@/lib/messages'
import { supabase } from '@/lib/supabase'

const m = messages.auth

export const Route = createFileRoute('/login')({
  beforeLoad: async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session) throw redirect({ to: '/' })
  },
  component: LoginPage,
})

function LoginPage() {
  const navigate = useNavigate()
  return (
    <AuthLayout>
      <AuthHeading title={m.login.title} subtitle={m.login.subtitle} />
      <LoginForm
        onSubmit={async (credentials) => {
          const { error } = await supabase.auth.signInWithPassword(credentials)
          if (error) return mapAuthError(error)
          await navigate({ to: '/' })
          return null
        }}
      />
      <Link
        to="/recupero-password"
        className="mt-6 inline-block text-sm text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
      >
        {m.login.forgot}
      </Link>
    </AuthLayout>
  )
}
