import { EnvelopeSimpleIcon } from '@phosphor-icons/react'
import { createFileRoute, Link, redirect, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { AuthHeading, AuthLayout } from '@/components/auth/AuthLayout'
import { SignupForm } from '@/components/auth/forms'
import { mapAuthError } from '@/lib/auth'
import { legal } from '@/lib/legal'
import { messages } from '@/lib/messages'
import { usePageTitle } from '@/lib/pageTitle'
import { supabase } from '@/lib/supabase'

const m = messages.auth

export const Route = createFileRoute('/registrati')({
  beforeLoad: async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session) throw redirect({ to: '/' })
  },
  component: SignupPage,
})

function SignupPage() {
  usePageTitle(m.signup.title)
  const navigate = useNavigate()
  const [sent, setSent] = useState(false)
  return (
    <AuthLayout>
      {sent ? (
        <div className="space-y-4" role="status">
          <span className="grid size-12 place-items-center rounded-lg bg-accent text-accent-foreground">
            <EnvelopeSimpleIcon size={24} weight="duotone" />
          </span>
          <AuthHeading title={m.signup.sentTitle} subtitle={m.signup.sent} />
        </div>
      ) : (
        <>
          <AuthHeading title={m.signup.title} subtitle={m.signup.subtitle} />
          <SignupForm
            onSubmit={async ({ full_name, email, password }) => {
              const { data, error } = await supabase.auth.signUp({
                email,
                password,
                options: {
                  // Prova del consenso: quando e a quale versione dei testi.
                  data: {
                    full_name,
                    terms_accepted_at: new Date().toISOString(),
                    terms_version: legal.version,
                  },
                  emailRedirectTo: `${window.location.origin}/login`,
                },
              })
              if (error) return mapAuthError(error)
              // Con la conferma email attiva non c'è ancora una sessione: si attende il link.
              if (!data.session) {
                setSent(true)
                return null
              }
              await navigate({ to: '/' })
              return null
            }}
          />
        </>
      )}
      <p className="mt-6 text-sm text-muted-foreground">
        {m.signup.hasAccount}{' '}
        <Link to="/login" className="font-medium text-foreground underline-offset-4 hover:underline">
          {messages.auth.login.title}
        </Link>
      </p>
    </AuthLayout>
  )
}
