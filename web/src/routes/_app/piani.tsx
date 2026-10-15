import { useQuery } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { Plans } from '@/components/plans/Plans'
import { messages } from '@/lib/messages'
import { planLimitsQuery, planUsageQuery } from '@/lib/plans'
import { usePageTitle } from '@/lib/pageTitle'

const m = messages.app.plans

export const Route = createFileRoute('/_app/piani')({
  component: PlansPage,
})

function PlansPage() {
  usePageTitle(m.title)
  const { user } = Route.useRouteContext()
  const usage = useQuery(planUsageQuery(user.id))
  const limits = useQuery(planLimitsQuery())

  return (
    <section className="space-y-6">
      <h1 className="text-xl font-semibold tracking-tight">{m.title}</h1>
      {usage.isSuccess && limits.isSuccess ? (
        <Plans usage={usage.data} limits={limits.data} />
      ) : usage.isError || limits.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : (
        <div aria-hidden className="h-64 max-w-6xl animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
