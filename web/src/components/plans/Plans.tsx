import { CheckIcon } from '@phosphor-icons/react'
import { proCheckoutUrl } from '@/lib/plans'
import { messages } from '@/lib/messages'
import { cn } from '@/lib/utils'

const m = messages.app.plans

function Features({ items }: { items: readonly string[] }) {
  return (
    <ul className="grid gap-2">
      {items.map((item) => (
        <li key={item} className="flex gap-2.5">
          <CheckIcon size={18} weight="bold" className="mt-0.5 shrink-0 text-primary" />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  )
}

/** Gratuito e Pro a confronto, con il piano attuale evidenziato e il link all'acquisto del Pro. */
export function Plans({ pro }: { pro: boolean }) {
  const checkout = proCheckoutUrl()
  return (
    <div className="grid max-w-3xl gap-4 md:grid-cols-2">
      <section
        aria-labelledby="plan-free"
        className={cn('grid content-start gap-4 rounded-lg border bg-card p-5', !pro && 'border-primary/50')}
      >
        <div className="grid gap-1">
          <div className="flex items-center justify-between gap-2">
            <h2 id="plan-free" className="text-base font-semibold">
              {m.free.name}
            </h2>
            {!pro && (
              <span className="rounded border border-primary/40 px-1.5 py-px text-xs text-primary">
                {m.active}
              </span>
            )}
          </div>
          <p className="text-muted-foreground">{m.free.tagline}</p>
        </div>
        <Features items={m.free.features} />
      </section>

      <section
        aria-labelledby="plan-pro"
        className={cn('grid content-start gap-4 rounded-lg border bg-card p-5', pro && 'border-primary/50')}
      >
        <div className="grid gap-1">
          <div className="flex items-center justify-between gap-2">
            <h2 id="plan-pro" className="text-base font-semibold">
              {m.pro.name}
            </h2>
            {pro && (
              <span className="rounded border border-primary/40 px-1.5 py-px text-xs text-primary">
                {m.active}
              </span>
            )}
          </div>
          <p className="text-muted-foreground">{m.pro.tagline}</p>
        </div>
        <Features items={m.pro.features} />
        {pro ? (
          <p className="text-muted-foreground">{m.activeBody}</p>
        ) : (
          <div className="grid gap-2">
            {checkout ? (
              <a
                href={checkout}
                className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors outline-none hover:bg-primary/90 focus-visible:ring-3 focus-visible:ring-ring/50"
              >
                {m.cta}
              </a>
            ) : (
              <>
                <button
                  type="button"
                  disabled
                  className="inline-flex h-9 cursor-not-allowed items-center justify-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground opacity-50"
                >
                  {m.ctaSoon}
                </button>
                <p className="text-xs text-muted-foreground">{m.ctaSoonHint}</p>
              </>
            )}
            <p className="text-xs text-muted-foreground">{m.billing}</p>
          </div>
        )}
      </section>
    </div>
  )
}
