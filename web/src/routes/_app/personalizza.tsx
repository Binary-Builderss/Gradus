import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { BrandForm } from '@/components/brand/BrandForm'
import { brandingQuery, proPlanQuery } from '@/lib/branding'
import { messages } from '@/lib/messages'
import { displayName, profileQuery } from '@/lib/profile'

const m = messages.app.customize

export const Route = createFileRoute('/_app/personalizza')({
  component: SettingsPage,
})

function SettingsPage() {
  const { user } = Route.useRouteContext()
  const branding = useQuery(brandingQuery(user.id))
  const pro = useQuery(proPlanQuery(user.id))
  const profile = useQuery(profileQuery(user.id))
  const ready = branding.isSuccess && pro.isSuccess

  return (
    <section className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-xl font-semibold tracking-tight">{m.title}</h1>
        {pro.isSuccess && (
          <span className="rounded-md border px-2 py-0.5 text-xs font-medium text-muted-foreground">
            {pro.data ? m.plan.pro : m.plan.free}
          </span>
        )}
        {pro.isSuccess && !pro.data && (
          <Link
            to="/piani"
            className="inline-flex h-8 items-center rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground transition-colors outline-none hover:bg-primary/90 focus-visible:ring-3 focus-visible:ring-ring/50"
          >
            {m.upgrade}
          </Link>
        )}
      </div>
      <div className="grid gap-1">
        <h2 className="text-sm font-semibold">{m.brand.title}</h2>
        <p className="max-w-prose text-muted-foreground">{m.brand.intro}</p>
      </div>
      {branding.isError || pro.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : ready ? (
        <BrandForm
          coachId={user.id}
          fallbackName={displayName(profile.data, user.email)}
          initial={branding.data}
          pro={pro.data}
        />
      ) : (
        <div aria-hidden className="h-64 animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
