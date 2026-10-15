import { useQuery } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { DangerZone } from '@/components/account/DangerZone'
import { PasswordReset } from '@/components/brand/PasswordReset'
import { ProfileForm } from '@/components/brand/ProfileForm'
import { messages } from '@/lib/messages'
import { profileQuery } from '@/lib/profile'
import { usePageTitle } from '@/lib/pageTitle'

const m = messages.app.account

export const Route = createFileRoute('/_app/profilo')({
  component: ProfilePage,
})

function ProfilePage() {
  usePageTitle(m.profile.title)
  const { user } = Route.useRouteContext()
  const profile = useQuery(profileQuery(user.id))

  return (
    <section className="space-y-6">
      <div className="grid gap-1">
        <h1 className="text-xl font-semibold tracking-tight">{m.profile.title}</h1>
        <p className="max-w-prose text-muted-foreground">{m.profile.intro}</p>
      </div>
      {profile.isSuccess ? (
        <>
          <ProfileForm userId={user.id} profile={profile.data} />
          {profile.data.email && (
            <div className="max-w-md border-t pt-6">
              <PasswordReset email={profile.data.email} />
            </div>
          )}
          {profile.data.email && (
            <div className="max-w-md border-t pt-6">
              <DangerZone userId={user.id} email={profile.data.email} />
            </div>
          )}
        </>
      ) : profile.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : (
        <div aria-hidden className="h-40 max-w-md animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
