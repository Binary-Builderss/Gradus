import { UsersThreeIcon } from '@phosphor-icons/react'
import { createFileRoute } from '@tanstack/react-router'
import { Steps } from '@/components/brand'
import { messages } from '@/lib/messages'

const m = messages.app.athletes

export const Route = createFileRoute('/_app/')({
  component: AthletesPage,
})

function AthletesPage() {
  return (
    <section className="space-y-8">
      <h1 className="font-display text-5xl font-bold uppercase">{m.title}</h1>
      <div className="relative overflow-hidden rounded-xl border bg-card p-8 sm:p-10">
        <Steps className="absolute right-8 bottom-8 hidden opacity-60 sm:flex" />
        <div className="relative max-w-md space-y-4">
          <span className="grid size-12 place-items-center rounded-lg bg-accent text-accent-foreground">
            <UsersThreeIcon size={26} weight="duotone" />
          </span>
          <h2 className="font-display text-2xl font-semibold uppercase">{m.emptyTitle}</h2>
          <p className="text-muted-foreground">{m.emptyBody}</p>
        </div>
      </div>
    </section>
  )
}
