import { useQuery } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { BrandForm } from '@/components/brand/BrandForm'
import { brandingQuery, proPlanQuery } from '@/lib/branding'
import { messages } from '@/lib/messages'

const m = messages.app.settings

export const Route = createFileRoute('/_app/impostazioni')({
  component: SettingsPage,
})

function SettingsPage() {
  const { user } = Route.useRouteContext()
  const branding = useQuery(brandingQuery(user.id))
  const pro = useQuery(proPlanQuery(user.id))
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
        <BrandForm coachId={user.id} fallbackName={user.email ?? ''} initial={branding.data} pro={pro.data} />
      ) : (
        <div aria-hidden className="h-64 animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
