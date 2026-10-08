import { EnvelopeSimpleIcon } from '@phosphor-icons/react'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useState } from 'react'
import { AuthHeading, AuthLayout } from '@/components/auth/AuthLayout'
import { RecoveryForm } from '@/components/auth/forms'
import { mapAuthError } from '@/lib/auth'
import { messages } from '@/lib/messages'
import { supabase } from '@/lib/supabase'

const m = messages.auth

export const Route = createFileRoute('/recupero-password')({
  component: RecoveryPage,
})

function RecoveryPage() {
  const [sent, setSent] = useState(false)
  return (
    <AuthLayout>
      {sent ? (
        <div className="space-y-4" role="status">
          <span className="grid size-12 place-items-center rounded-lg bg-accent text-accent-foreground">
            <EnvelopeSimpleIcon size={24} weight="duotone" />
          </span>
          <AuthHeading title={m.recovery.sentTitle} subtitle={m.recovery.sent} />
        </div>
      ) : (
        <>
          <AuthHeading title={m.recovery.title} subtitle={m.recovery.subtitle} />
          <RecoveryForm
            onSubmit={async ({ email }) => {
              const { error } = await supabase.auth.resetPasswordForEmail(email, {
                redirectTo: `${window.location.origin}/nuova-password`,
              })
              // Stessa risposta che l'email esista o no: non riveliamo quali account ci sono.
              if (error && (error.status === 429 || error.name === 'AuthRetryableFetchError')) {
                return mapAuthError(error)
              }
              setSent(true)
              return null
            }}
          />
        </>
      )}
      <Link
        to="/login"
        className="mt-6 inline-block text-sm text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
      >
        {m.backToLogin}
      </Link>
    </AuthLayout>
  )
}
