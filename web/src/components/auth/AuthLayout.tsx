import type { ReactNode } from 'react'
import { Wordmark } from '@/components/brand'
import { messages } from '@/lib/messages'

/** Schermate di accesso: un solo pannello centrato, senza decorazioni. */
export function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <main className="grid min-h-dvh place-items-center px-4 py-10">
      <div className="w-full max-w-sm space-y-8">
        <Wordmark className="h-12" />
        <div className="rounded-lg border bg-card p-6 shadow-sm sm:p-8">{children}</div>
        <nav className="flex gap-4 text-xs text-muted-foreground">
          <a href="/termini" className="underline-offset-4 hover:text-foreground hover:underline">
            {messages.legal.footer.terms}
          </a>
          <a href="/privacy" className="underline-offset-4 hover:text-foreground hover:underline">
            {messages.legal.footer.privacy}
          </a>
          <a href="/assistenza" className="underline-offset-4 hover:text-foreground hover:underline">
            {messages.legal.footer.support}
          </a>
        </nav>
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
