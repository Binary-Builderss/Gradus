import { useQuery } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import { Plans } from '@/components/plans/Plans'
import { proPlanQuery } from '@/lib/branding'
import { messages } from '@/lib/messages'

const m = messages.app.plans

export const Route = createFileRoute('/_app/piani')({
  component: PlansPage,
})

function PlansPage() {
  const { user } = Route.useRouteContext()
  const pro = useQuery(proPlanQuery(user.id))

  return (
    <section className="space-y-6">
      <h1 className="text-xl font-semibold tracking-tight">{m.title}</h1>
      {pro.isSuccess ? (
        <Plans pro={pro.data} />
      ) : pro.isError ? (
        <p role="alert" className="text-destructive">
          {m.loadError}
        </p>
      ) : (
        <div aria-hidden className="h-64 max-w-3xl animate-pulse rounded-lg border bg-muted/40" />
      )}
    </section>
  )
}
