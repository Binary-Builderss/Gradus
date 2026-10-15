import { CheckIcon } from '@phosphor-icons/react'
import { checkoutUrl, PLANS, type Plan, type PlanUsage } from '@/lib/plans'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.plans

function Usage({ usage }: { usage: PlanUsage }) {
  const { athletes, athleteLimit } = usage
  const percent = athleteLimit === null ? 0 : Math.min(100, Math.round((athletes / athleteLimit) * 100))
  return (
    <div className="grid max-w-md gap-2">
      <p className="font-medium">
        {athleteLimit === null ? m.usageUnlimited(athletes) : m.usage(athletes, athleteLimit)}
      </p>
      {athleteLimit !== null && (
        <div
          role="progressbar"
          aria-label={m.usage(athletes, athleteLimit)}
          aria-valuemin={0}
          aria-valuemax={athleteLimit}
          aria-valuenow={Math.min(athletes, athleteLimit)}
          className="h-1.5 overflow-hidden rounded-full bg-muted"
        >
          <div className="h-full rounded-full bg-primary" style={{ width: `${percent}%` }} />
        </div>
      )}
    </div>
  )
}

function Cta({ plan }: { plan: Plan }) {
  const url = checkoutUrl(plan)
  const label = m.cta(m.tiers[plan].name)
  if (url)
    return (
      <a
        href={url}
        className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors outline-none hover:bg-primary/90 focus-visible:ring-3 focus-visible:ring-ring/50"
      >
        {label}
      </a>
    )
  return (
    <button
      type="button"
      disabled
      className="inline-flex h-9 cursor-not-allowed items-center justify-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground opacity-50"
    >
      {m.ctaSoon}
    </button>
  )
}

/** I quattro livelli a confronto: il tuo evidenziato, quelli sopra con il link all'acquisto. */
export function Plans({ usage, limits }: { usage: PlanUsage; limits: Record<Plan, number | null> }) {
  const currentIndex = PLANS.indexOf(usage.plan)
  const someSoon = PLANS.some((plan, index) => index > currentIndex && checkoutUrl(plan) === null)
  return (
    <div className="grid gap-6">
      <Usage usage={usage} />
      <div className="grid max-w-6xl gap-4 md:grid-cols-2 xl:grid-cols-4">
        {PLANS.map((plan, index) => {
          const tier = m.tiers[plan]
          const current = plan === usage.plan
          return (
            <section
              key={plan}
              aria-labelledby={`plan-${plan}`}
              className={cn(
                'grid content-start gap-4 rounded-lg border bg-card p-5',
                current && 'border-primary/50',
              )}
            >
              <div className="grid gap-1">
                <div className="flex items-center justify-between gap-2">
                  <h2 id={`plan-${plan}`} className="text-base font-semibold">
                    {tier.name}
                  </h2>
                  {current && (
                    <span className="rounded border border-primary/40 px-1.5 py-px text-xs text-primary">
                      {m.active}
                    </span>
                  )}
                </div>
                <p className="text-muted-foreground">{tier.tagline}</p>
              </div>
              <ul className="grid gap-2">
                {[m.limitLine(limits[plan]), ...tier.features].map((item) => (
                  <li key={item} className="flex gap-2.5">
                    <CheckIcon size={18} weight="bold" className="mt-0.5 shrink-0 text-primary" />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
              {index > currentIndex && (
                <div className="mt-auto grid gap-2 pt-2">
                  <Cta plan={plan} />
                  <p className="text-xs text-muted-foreground">{m.billing}</p>
                </div>
              )}
            </section>
          )
        })}
      </div>
      {someSoon && <p className="max-w-md text-sm text-muted-foreground">{m.ctaSoonHint}</p>}
    </div>
  )
}
