import type { ReactNode } from 'react'
import { Steps, Wordmark } from '@/components/brand'
import { messages } from '@/lib/messages'

const b = messages.brand

/** Schermate di accesso: pannello del marchio a sinistra (solo desktop), form a destra. */
export function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="grid min-h-dvh lg:grid-cols-[1.1fr_1fr]">
      <aside className="relative hidden flex-col justify-between overflow-hidden border-r bg-sidebar p-12 lg:flex">
        <div
          aria-hidden
          className="pointer-events-none absolute -top-1/3 -left-1/4 size-[80vh] rounded-full bg-[radial-gradient(circle,var(--glow),transparent_65%)]"
        />
        <Wordmark className="relative" />
        <div className="relative space-y-8">
          <Steps />
          <h2 className="font-display text-6xl leading-[0.92] font-bold uppercase xl:text-7xl">
            {b.claimStart} <span className="text-primary">{b.claimEnd}</span>
          </h2>
          <p className="max-w-[42ch] text-lg text-muted-foreground">{b.body}</p>
        </div>
      </aside>

      <main className="flex flex-col justify-center px-5 py-10 sm:px-12">
        <div className="mx-auto w-full max-w-sm animate-in duration-500 fade-in slide-in-from-bottom-2 motion-reduce:animate-none">
          <Wordmark className="mb-10 block lg:hidden" />
          {children}
        </div>
      </main>
    </div>
  )
}

export function AuthHeading({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <header className="mb-8 space-y-2">
      <h1 className="font-display text-4xl font-bold uppercase">{title}</h1>
      <p className="text-muted-foreground">{subtitle}</p>
    </header>
  )
}
