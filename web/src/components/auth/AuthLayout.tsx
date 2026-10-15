import type { ReactNode } from 'react'
import { Wordmark } from '@/components/brand'

/** Schermate di accesso: un solo pannello centrato, senza decorazioni. */
export function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="grid min-h-dvh place-items-center px-4 py-10">
      <div className="w-full max-w-sm space-y-8">
        <Wordmark className="h-12" />
        <div className="rounded-lg border bg-card p-6 shadow-sm sm:p-8">{children}</div>
      </div>
    </main>
  )
}

export function AuthHeading({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <header className="mb-6 space-y-1">
      <h1 className="text-xl font-semibold tracking-tight">{title}</h1>
      <p className="text-sm text-muted-foreground">{subtitle}</p>
    </header>
  )
}
